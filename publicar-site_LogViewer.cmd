@echo off
setlocal EnableDelayedExpansion

:: ════════════════════════════════════════════════════════════════════
::  The Absolute LogViewer  --  Publish SITE-ONLY
:: ════════════════════════════════════════════════════════════════════
::  Atualiza APENAS o site (landing page) no repo dist e faz push.
::  NAO compila, NAO cria Release, NAO mexe em csproj/pubxml/version.json
::  nem nos binarios (ClickOnce / Standalone / Portable ficam intactos).
::
::  Usar quando so mudou a landing page: textos, traducoes, CSS, JS,
::  imagens, links (ex: o link do mBrothers). Atualiza o GitHub Pages
::  em ~1 min sem o upload de ~225 MB das Releases.
::
::  Para uma NOVA VERSAO da app usa-se o publicar_LogViewer.cmd (faz tudo).
:: ════════════════════════════════════════════════════════════════════

set "DIST_DIR=%~dp0"
set "CSPROJ=%~dp0..\LogViewer\LogViewer.csproj"
set "DIST_INDEX=%~dp0index.html"

echo.
echo ==========================================
echo   The Absolute LogViewer  --  Publish SITE
echo ==========================================
echo.

:: ── 1. Ler versao ATUAL do .csproj (sem bump) ─────────────────
echo [1/4] A ler versao atual do .csproj...
if not exist "%CSPROJ%" (
    echo [ERRO] Nao encontrou: %CSPROJ%
    pause & exit /b 1
)
:: tokens=* tira os espacos a esquerda para a linha comecar em "<"
for /f "tokens=*" %%a in ('findstr /r /c:"<Version>[0-9][0-9.]*</Version>" "%CSPROJ%"') do set LINE=%%a
for /f "tokens=2 delims=><" %%b in ("%LINE%") do set VERSION=%%b
if "%VERSION%"=="" (
    echo [ERRO] Nao foi possivel ler a versao do .csproj.
    pause & exit /b 1
)
echo       Versao: %VERSION%  ^(sem bump^)
echo       OK

:: -- 2. Validar o site ---------------------------------------
:: ESTA PASTA E A FONTE DO SITE. Edita-se aqui e publica-se daqui, igual ao
:: ExplorerFocus. Ate 2026-08-18 a fonte vivia em ..\LogViewer\docs\ e era
:: copiada para ca por robocopy; havia duas copias e editar a errada perdia
:: o trabalho todo. Deixou de haver copia: nao ha robocopy nenhum.
echo [2/4] A validar o site...
if not exist "%DIST_INDEX%" (
    echo [ERRO] Nao encontrou o site: %DIST_INDEX%
    pause & exit /b 1
)
echo       OK

:: -- 3. Escrever a versao no index.html ----------------------
echo [3/4] A escrever a versao no site...
:: Nao ha marcador "__VERSION__": como o ficheiro escrito e o MESMO que se
:: volta a ler no publish seguinte, um marcador era gasto a primeira vez e
:: nunca mais havia o que substituir -- o numero congelava em silencio.
:: Reescreve-se a versao ANTERIOR, e CONTA-SE antes: se o padrao deixar de
:: casar (alguem mexeu no HTML), isto FALHA em vez de passar em claro.
:: UTF-8 SEM BOM: o PowerShell 5.1 usa ANSI por omissao e ha acentuacao.
:: O ">" do HTML vai como \x3E no regex: assim nao ha um ">" literal na linha
:: e nao ha duvida nenhuma sobre o cmd o ler como redireccao. IDENTICA a do
:: publicar_LogViewer.cmd -- se mexeres numa, mexe na outra.
powershell -NoProfile -Command "$q=[char]34; $p='%DIST_INDEX%'; $v='%VERSION%'; $c=[IO.File]::ReadAllText($p,[Text.Encoding]::UTF8); $p1='(softwareVersion'+$q+'\s*:\s*'+$q+')[\d.]+'; $p2='(class='+$q+'ver-badge'+$q+'\x3Ev)[\d.]+'; if (([regex]::Matches($c,$p1)).Count -lt 1) { exit 2 }; if (([regex]::Matches($c,$p2)).Count -lt 1) { exit 3 }; $c=[regex]::Replace($c,$p1,('${1}'+$v)); $c=[regex]::Replace($c,$p2,('${1}'+$v)); [IO.File]::WriteAllText($p,$c,(New-Object Text.UTF8Encoding($false)))"
if errorlevel 1 (
    echo [ERRO] Falhou a injetar a versao no index.html.
    pause & exit /b 1
)
echo       Versao injetada: v%VERSION%
echo       OK

:: -- 4. git add (so do site) + commit + push -----------------
echo [4/4] git add ^(so site^) + commit + push...
cd /d "%DIST_DIR%"

:: Stage EXPLICITO dos ficheiros do site, para um run so-site nunca
:: arrastar por engano ClickOnce / version.json / outras pendencias do
:: working tree. As pastas cobrem todo o seu conteudo; os ficheiros da
:: raiz sao listados um a um.
:: NOTA: se um dia adicionares um ficheiro de site NOVO na raiz de docs\
:: (ex: robots.txt, sitemap.xml), acrescenta-o tambem a esta lista.
git add index.html README.md robots.txt sitemap.xml assets css i18n js "app-icon-*.png" "screenshot-*.png" social-preview.jpg
if errorlevel 1 (
    echo [ERRO] git add falhou. Estas no repo dist certo?
    pause & exit /b 1
)

:: Mostrar o que vai ser commitado.
echo.
echo       --- ficheiros do site staged ---
git diff --cached --name-only
echo       --------------------------------
echo.

git commit -m "Site: atualizacao da landing page (v%VERSION%)"
if errorlevel 1 (
    echo       [AVISO] Nada para commit ^(o site ja estava sincronizado^).
    echo               A tentar push na mesma ^(caso haja commits por enviar^)...
)

git push origin main
if errorlevel 1 (
    echo [ERRO] git push falhou.
    echo        Verifica 'git status' e 'git auth status' do gh/credenciais.
    pause & exit /b 1
)
echo       OK

echo.
echo ==========================================
echo   Site publicado com sucesso!  v%VERSION%
echo.
echo   Landing:  https://nunex-mbrothers.github.io/TheAbsoluteLogViewer/
echo   ^(GitHub Pages pode demorar ~1 min a atualizar^)
echo.
echo   Sem build, sem Release, binarios intactos.
echo ==========================================
echo.
pause
