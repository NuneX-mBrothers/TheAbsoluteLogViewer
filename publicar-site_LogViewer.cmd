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
set "DOCS_DIR=%~dp0..\LogViewer\docs"
set "DIST_INDEX=%~dp0index.html"

echo.
echo ==========================================
echo   The Absolute LogViewer  --  Publish SITE
echo ==========================================
echo.

:: ── 1. Ler versao ATUAL do .csproj (sem bump) ─────────────────
echo [1/5] A ler versao atual do .csproj...
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

:: ── 2. Validar a origem do site ───────────────────────────────
echo [2/5] A validar docs\index.html...
if not exist "%DOCS_DIR%\index.html" (
    echo [ERRO] %DOCS_DIR%\index.html nao encontrado.
    pause & exit /b 1
)
echo       OK

:: ── 3. Copiar o SITE (docs\ inteiro) para o repo dist ─────────
echo [3/5] A copiar o site ^(docs\^) para o dist...
:: Igual ao passo [5] do publicar_LogViewer.cmd: copia recursiva preservando
:: estrutura (css\ js\ i18n\ assets\ + screenshots + app-icons).
:: SEM /MIR (nao apaga ClickOnce / StandAlone\ / Portable\). /XF
:: exclui os backups __index*.html da pasta docs.
robocopy "%DOCS_DIR%" "%~dp0." /E /XF "__*.html" /R:2 /W:1 /NFL /NDL /NJH /NJS /NP >nul
:: robocopy: codigos 0-7 = sucesso; >=8 = erro real.
if errorlevel 8 (
    echo [ERRO] robocopy falhou a copiar o site.
    pause & exit /b 1
)
echo       Site copiado ^(css/js/i18n/assets + imagens^).
echo       OK

:: ── 4. Injetar a versao no index.html copiado ─────────────────
echo [4/5] A injetar a versao no index.html...
:: Ler e escrever explicitamente em UTF-8 SEM BOM (o PowerShell 5.1 usa ANSI por
:: omissao, e "Set-Content -Encoding UTF8" escreveria COM BOM).
powershell -NoProfile -Command "$p='%DIST_INDEX%'; $c=[System.IO.File]::ReadAllText($p,[System.Text.Encoding]::UTF8) -replace '__VERSION__','%VERSION%'; [System.IO.File]::WriteAllText($p,$c,(New-Object System.Text.UTF8Encoding($false)))"
if errorlevel 1 (
    echo [ERRO] Falhou a injetar a versao no index.html.
    pause & exit /b 1
)
echo       Versao injetada: v%VERSION%
echo       OK

:: ── 5. git add (so do site) + commit + push ───────────────────
echo [5/5] git add ^(so site^) + commit + push...
cd /d "%DIST_DIR%"

:: Stage EXPLICITO dos ficheiros do site, para um run so-site nunca
:: arrastar por engano ClickOnce / version.json / outras pendencias do
:: working tree. As pastas cobrem todo o seu conteudo; os ficheiros da
:: raiz sao listados um a um.
:: NOTA: se um dia adicionares um ficheiro de site NOVO na raiz de docs\
:: (ex: robots.txt, sitemap.xml), acrescenta-o tambem a esta lista.
git add index.html assets css i18n js "app-icon-*.png" "screenshot-*.png" social-preview.jpg
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
