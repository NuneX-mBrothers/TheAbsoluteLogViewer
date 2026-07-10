@echo off
setlocal EnableDelayedExpansion

:: ════════════════════════════════════════════════════════════════════
::  The Absolute LogViewer  --  PUBLICAR (prepara + envia, tudo num passo)
:: ════════════════════════════════════════════════════════════════════
::  Substitui o antigo par 1-prepare + 2-publish. Estavam separados porque
::  no meio era preciso ir ao Visual Studio fazer Publish a mao; hoje o
::  ClickOnce e compilado aqui via MSBuild do VS, por isso nao ha pausa.
::
::  Ciclo completo de uma release:
::   1) verifica ferramentas e caminhos ANTES de tocar em nada
::   2) le a versao atual e pede a nova (N.N.N.N)
::   3) confirma que a tag ainda nao existe (falha em 5s, nao em 5min)
::   4) atualiza o .csproj e o ClickOnceProfile.pubxml
::   5) copia o site (docs\) e injeta a versao no index.html
::   6) para a app, limpa bin\Release + obj
::   7) compila as 3 edicoes: StandAlone -> ClickOnce -> Portable
::   8) renomeia o Portable e cria os .zip
::   9) gera o version.json (versao + data + SHA-256) p/ o auto-update
::  10) cria a GitHub Release com os 4 ficheiros
::  11) commit + push do repo dist (site + ClickOnce + version.json)
::
::  O codigo e PRIVADO (repo LogViewer) e NAO e tocado por este script
::  alem do bump de versao -- esse commit e teu, ver o lembrete no fim.
::  Os binarios grandes vivem nas Releases, nunca no repo.
::  Para mudar SO o site (textos/traducoes), usa publicar-site_LogViewer.cmd.
:: ════════════════════════════════════════════════════════════════════

set "DIST_DIR=%~dp0"
set "PROJ_DIR=%~dp0..\LogViewer"
set "PROJ=%PROJ_DIR%\LogViewer.csproj"
set "PUBXML=%PROJ_DIR%\Properties\PublishProfiles\ClickOnceProfile.pubxml"
set "DOCS_DIR=%PROJ_DIR%\docs"
set "BIN=%PROJ_DIR%\bin\Release"
set "OBJ=%PROJ_DIR%\obj"
set "APPPUB=%PROJ_DIR%\bin\Release\net10.0-windows\win-x64\app.publish"

set "DIST_INDEX=%~dp0index.html"
set "VERSIONJSON=%~dp0StandAlone\version.json"

set "SA_DIR=%~dp0StandAlone"
set "SA_EXE=%SA_DIR%\LogViewer.exe"
set "SA_ZIP=%SA_DIR%\LogViewer.zip"

set "PT_DIR=%~dp0Portable"
set "PT_RAW=%PT_DIR%\LogViewer.exe"
set "PT_EXE=%PT_DIR%\LogViewerPortable.exe"
set "PT_PDB=%PT_DIR%\LogViewer.pdb"
set "PT_ZIP=%PT_DIR%\LogViewerPortable.zip"

set "REPO=NuneX-mBrothers/TheAbsoluteLogViewer"

:: %ProgramFiles(x86)% tem parentesis: TEM de ser expandido fora de qualquer
:: bloco ( ... ), senao o ")" fecha o bloco e o cmd rebenta.
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"

echo.
echo ==========================================
echo   The Absolute LogViewer  --  PUBLICAR
echo ==========================================
echo.

:: ── 1. Pre-flight ────────────────────────────────────────────
:: Tudo o que pode falhar e verificado ANTES de editar o csproj, apagar o
:: bin ou compilar. O 1-prepare antigo bumpava a versao e so la ao fundo
:: descobria que o MSBuild nao existia, deixando o repo a meio.
echo [1/11] Verificacoes previas...

if not exist "%PROJ%"  ( echo [ERRO] Nao encontrou: %PROJ%  & pause & exit /b 1 )
if not exist "%PUBXML%" (
    for /r "%PROJ_DIR%" %%f in (ClickOnceProfile.pubxml) do set "PUBXML=%%f"
)
if not exist "%PUBXML%" ( echo [ERRO] ClickOnceProfile.pubxml nao encontrado. & pause & exit /b 1 )
if not exist "%DOCS_DIR%\index.html" ( echo [ERRO] Nao encontrou: %DOCS_DIR%\index.html & pause & exit /b 1 )
if not exist "%SA_DIR%" ( echo [ERRO] Falta a pasta StandAlone\ em %DIST_DIR% & pause & exit /b 1 )

where dotnet >nul 2>&1
if errorlevel 1 ( echo [ERRO] 'dotnet' nao esta no PATH. Instala o .NET SDK 10. & pause & exit /b 1 )

where gh >nul 2>&1
if errorlevel 1 ( echo [ERRO] 'gh' nao esta no PATH. Instala o GitHub CLI. & pause & exit /b 1 )

gh auth status >nul 2>&1
if errorlevel 1 ( echo [ERRO] 'gh' sem login. Corre 'gh auth login'. & pause & exit /b 1 )

:: ClickOnce so se publica com o MSBuild do Visual Studio -- o dotnet publish
:: nao suporta o protocolo. Localizar agora, nao daqui a 3 minutos.
set "MSBUILD="
set "MSBTMP=%TEMP%\_lv_msbuild.txt"
if exist "%VSWHERE%" (
    "%VSWHERE%" -latest -prerelease -find "MSBuild\**\Bin\MSBuild.exe" > "%MSBTMP%" 2>nul
    set /p MSBUILD=<"%MSBTMP%"
    del "%MSBTMP%" 2>nul
)
if not defined MSBUILD (
    echo [ERRO] MSBuild do Visual Studio nao encontrado ^(necessario p/ ClickOnce^).
    pause & exit /b 1
)

:: Estamos mesmo dentro do repo dist?
cd /d "%DIST_DIR%"
git rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 ( echo [ERRO] %DIST_DIR% nao e um repositorio git. & pause & exit /b 1 )

echo        dotnet, gh ^(com login^), MSBuild e repo git: OK
echo        OK

:: ── 2. Ler a versao atual e pedir a nova ─────────────────────
echo [2/11] A ler a versao atual do LogViewer.csproj...
for /f "tokens=*" %%a in ('findstr /r "<Version>[0-9]" "%PROJ%"') do set LINE=%%a
for /f "tokens=2 delims=><" %%b in ("%LINE%") do set CURRENT=%%b
if "%CURRENT%"=="" ( echo [ERRO] Nao consegui ler o ^<Version^> do .csproj. & pause & exit /b 1 )
echo        Versao atual: %CURRENT%
echo        OK

echo [3/11] Nova versao N.N.N.N ^(Enter = manter %CURRENT%^):
set /p NEWVER=       Nova versao:
if "%NEWVER%"=="" set NEWVER=%CURRENT%
set NEWVER=%NEWVER:"=%

:: Validacao por regex (o findstr nao chega). Tem de ser 4 campos: o
:: version.json publica SEMPRE 4 campos, senao Version.TryParse("1.5.1")
:: devolve Revision=-1 e qualquer app com revisao real parece mais nova.
powershell -NoProfile -Command "if ('%NEWVER%' -notmatch '^\d+\.\d+\.\d+\.\d+$') { exit 1 }"
if errorlevel 1 (
    echo [ERRO] Formato invalido: %NEWVER%
    echo        Tem de ser N.N.N.N, por exemplo 1.5.1.7
    pause & exit /b 1
)

:: A tag ja existe? Descobrir AGORA, e nao depois de 3 edicoes compiladas.
gh release view "v%NEWVER%" --repo "%REPO%" >nul 2>&1
if not errorlevel 1 (
    echo [ERRO] A release v%NEWVER% ja existe em %REPO%.
    echo        Ou escolhe outra versao, ou apaga-a primeiro:
    echo          gh release delete v%NEWVER% --repo %REPO% --cleanup-tag
    pause & exit /b 1
)
echo        Nova versao: %NEWVER%   ^(tag v%NEWVER% livre^)
echo        OK

:: ── 4. Atualizar csproj + pubxml ─────────────────────────────
:: O .csproj e a UNICA fonte de verdade da versao. Daqui propaga-se para o
:: pubxml (ClickOnce), o version.json e o index.html -- tudo neste script.
echo [4/11] A atualizar LogViewer.csproj e ClickOnceProfile.pubxml...
powershell -NoProfile -Command "$p='%PROJ%'; $c=[IO.File]::ReadAllText($p); $c=$c -replace '<Version>.*?</Version>','<Version>%NEWVER%</Version>' -replace '<AssemblyVersion>.*?</AssemblyVersion>','<AssemblyVersion>%NEWVER%</AssemblyVersion>' -replace '<FileVersion>.*?</FileVersion>','<FileVersion>%NEWVER%</FileVersion>'; [IO.File]::WriteAllText($p,$c,(New-Object Text.UTF8Encoding($false)))"
if errorlevel 1 ( echo [ERRO] Falhou a atualizar o .csproj. & pause & exit /b 1 )

powershell -NoProfile -Command "$p='%PUBXML%'; $c=[IO.File]::ReadAllText($p); $c=$c -replace '<ApplicationVersion>.*?</ApplicationVersion>','<ApplicationVersion>%NEWVER%</ApplicationVersion>'; [IO.File]::WriteAllText($p,$c,(New-Object Text.UTF8Encoding($false)))"
if errorlevel 1 ( echo [ERRO] Falhou a atualizar o pubxml. & pause & exit /b 1 )
echo        OK: csproj + pubxml -^> %NEWVER%

:: ── 5. Copiar o site (docs\ inteiro) + injetar a versao ──────
echo [5/11] A copiar o site ^(docs\^) e a injetar a versao...
:: /E inclui subpastas; SEM /MIR para nao apagar o que ja existe no dist
:: (ClickOnce, StandAlone\, Portable\). /XF exclui os backups __index*.html.
robocopy "%DOCS_DIR%" "%~dp0." /E /XF "__*.html" /R:2 /W:1 /NFL /NDL /NJH /NJS /NP >nul
:: robocopy: 0-7 = sucesso; >=8 = erro real.
if errorlevel 8 ( echo [ERRO] robocopy falhou a copiar o site. & pause & exit /b 1 )

:: Ler e escrever em UTF-8 SEM BOM. O Windows PowerShell 5.1 usa ANSI por
:: omissao e o index.html tem caracteres nao-ASCII (aspas curvas, seta ->).
:: Nao usar "Set-Content -Encoding UTF8": no 5.1 isso escreve COM BOM.
powershell -NoProfile -Command "$p='%DIST_INDEX%'; $c=[IO.File]::ReadAllText($p,[Text.Encoding]::UTF8) -replace '__VERSION__','%NEWVER%'; [IO.File]::WriteAllText($p,$c,(New-Object Text.UTF8Encoding($false)))"
if errorlevel 1 ( echo [ERRO] Falhou a injetar a versao no index.html. & pause & exit /b 1 )
echo        Site copiado ^(css/js/i18n/assets^) + versao injetada: v%NEWVER%
echo        OK

:: ── 6. Parar a app + limpar artefactos ───────────────────────
:: Se o LogViewer estiver aberto a partir do bin\Release, o rmdir falha.
:: bin\Debug e preservado para nao estragar o F5 / o build manual.
echo [6/11] A parar o LogViewer ^(se aberto^) e a limpar bin\Release + obj...
taskkill /im LogViewer.exe /f >nul 2>&1
if exist "%BIN%" ( rmdir /s /q "%BIN%" & echo        Apagado: bin\Release\ )
if exist "%OBJ%" ( rmdir /s /q "%OBJ%" & echo        Apagado: obj\ )
echo        OK

:: ── 7. Compilar as 3 edicoes ─────────────────────────────────
:: Ordem: StandAlone -> ClickOnce -> Portable. As duas primeiras sao
:: framework-dependent; a Portable (self-contained) fica para o fim para
:: nao contaminar o bin\ partilhado das outras.
echo [7/11] A compilar as 3 edicoes...

echo        - restore...
dotnet restore "%PROJ%" >nul
if errorlevel 1 ( echo [ERRO] dotnet restore falhou. & pause & exit /b 1 )

echo        - StandAlone ^(single-file, framework-dependent^)...
:: Nao passar PublishProfile: a condicao "$(PublishProfile)==''" do csproj
:: e o que da o single-file. EnableCompressionInSingleFile fica DESLIGADO
:: (incompativel com SelfContained=false).
dotnet publish "%PROJ%" -c Release -p:PublishSingleFile=true -p:SelfContained=false -p:RuntimeIdentifier=win-x64 -p:IncludeNativeLibrariesForSelfExtract=true -p:IncludeAllContentForSelfExtract=true -p:DebugType=none -p:DebugSymbols=false -p:PublishDir="%SA_DIR%\\" --nologo -v minimal
if errorlevel 1 ( echo [ERRO] build StandAlone falhou. & pause & exit /b 1 )
if not exist "%SA_EXE%" ( echo [ERRO] Nao gerou %SA_EXE% & pause & exit /b 1 )
echo          OK: %SA_EXE%

echo        - ClickOnce ^(MSBuild do Visual Studio^)...
"%MSBUILD%" "%PROJ%" /t:Publish /p:PublishProfile=ClickOnceProfile /p:Configuration=Release /restore /v:minimal /nologo
if errorlevel 1 ( echo [ERRO] build ClickOnce falhou. & pause & exit /b 1 )
if not exist "%APPPUB%\LogViewer.application" (
    echo [ERRO] ClickOnce: nao gerou app.publish em:
    echo        %APPPUB%
    pause & exit /b 1
)
echo          A copiar deployment ClickOnce para o repo dist...
:: Purgar as pastas versionadas antigas ANTES do xcopy (ja depois de o build
:: ter corrido bem, portanto sem risco de ficar sem deployment). O xcopy faz
:: merge e nunca apaga, por isso "Application Files\" acumulava uma pasta por
:: release e o git add -A comitava-as todas. O LogViewer.application so
:: referencia a versao corrente; as anteriores sao peso morto no repo publico.
if exist "%~dp0Application Files" (
    echo          A limpar versoes ClickOnce antigas...
    rmdir /s /q "%~dp0Application Files"
    if exist "%~dp0Application Files" ( echo [ERRO] nao consegui limpar "Application Files". & pause & exit /b 1 )
)
:: Cada copy e verificado: se o manifesto .application falhasse mas o xcopy
:: seguinte corresse bem, ficavamos com binarios novos + manifesto velho
:: (ClickOnce partido) e o script dizia OK.
copy /Y "%APPPUB%\LogViewer.application" "%~dp0" >nul
if errorlevel 1 ( echo [ERRO] falhou a copiar LogViewer.application. & pause & exit /b 1 )
copy /Y "%APPPUB%\setup.exe" "%~dp0" >nul
if errorlevel 1 ( echo [ERRO] falhou a copiar setup.exe. & pause & exit /b 1 )
xcopy /E /I /Y "%APPPUB%\Application Files" "%~dp0Application Files" >nul
if errorlevel 1 ( echo [ERRO] falhou a copiar os ficheiros ClickOnce. & pause & exit /b 1 )
echo          OK: LogViewer.application + setup.exe + Application Files\

echo        - Portable ^(self-contained, ReadyToRun - pode demorar 1-2 min^)...
dotnet publish "%PROJ%" -c Release -p:PublishSingleFile=true -p:SelfContained=true -p:RuntimeIdentifier=win-x64 -p:IncludeNativeLibrariesForSelfExtract=true -p:PublishReadyToRun=true -p:DebugType=none -p:DebugSymbols=false -p:PublishDir="%PT_DIR%\\" --nologo -v minimal
if errorlevel 1 ( echo [ERRO] build Portable falhou. & pause & exit /b 1 )
if not exist "%PT_RAW%" (
    if not exist "%PT_EXE%" ( echo [ERRO] Nao gerou o Portable .exe em %PT_DIR% & pause & exit /b 1 )
)
echo          OK: %PT_DIR%
echo        OK

:: ── 8. Renomear o Portable + criar os .zip ───────────────────
:: Os .zip existem para PCs/organizacoes que bloqueiam downloads de .exe.
echo [8/11] A renomear o Portable e a criar os .zip...

if exist "%PT_PDB%" ( del "%PT_PDB%" & echo        Apagado: LogViewer.pdb )
if exist "%SA_ZIP%" ( del "%SA_ZIP%" )
if exist "%PT_ZIP%" ( del "%PT_ZIP%" )
if exist "%PT_EXE%" ( del "%PT_EXE%" )

if exist "%PT_RAW%" (
    ren "%PT_RAW%" "LogViewerPortable.exe"
    echo        Renomeado: LogViewer.exe -^> LogViewerPortable.exe
)
if not exist "%PT_EXE%" ( echo [ERRO] LogViewerPortable.exe nao existe apos o rename. & pause & exit /b 1 )

powershell -NoProfile -Command "Compress-Archive -Path '%SA_EXE%' -DestinationPath '%SA_ZIP%' -Force"
if errorlevel 1 ( echo [ERRO] Falhou a criar o LogViewer.zip. & pause & exit /b 1 )
powershell -NoProfile -Command "Compress-Archive -Path '%PT_EXE%' -DestinationPath '%PT_ZIP%' -Force"
if errorlevel 1 ( echo [ERRO] Falhou a criar o LogViewerPortable.zip. & pause & exit /b 1 )
echo        Criados: LogViewer.zip + LogViewerPortable.zip
echo        OK

:: ── 9. Gerar o version.json ──────────────────────────────────
:: Lido pelo UpdateService das edicoes StandAlone e Portable (o ClickOnce
:: tem mecanismo proprio). A "version" TEM de ter 4 campos. O SHA-256 e
:: calculado sobre os MESMOS bytes que vao para a Release (ja renomeados),
:: e o UpdateService verifica-o no .exe descarregado antes de instalar.
:: A data "released" e preservada se ja estiveres a republicar a mesma versao.
echo [9/11] A gerar o version.json ^(versao + data + SHA-256^)...
powershell -NoProfile -Command "$vj='%VERSIONJSON%'; $ver='%NEWVER%'; $rel=(Get-Date -Format yyyy-MM-dd); if (Test-Path $vj) { try { $o=Get-Content $vj -Raw | ConvertFrom-Json; if ($o.version -eq $ver -and $o.released) { $rel=$o.released } } catch {} }; $s=[Security.Cryptography.SHA256]::Create(); $h1=[BitConverter]::ToString($s.ComputeHash([IO.File]::ReadAllBytes('%SA_EXE%'))).Replace('-',''); $h2=[BitConverter]::ToString($s.ComputeHash([IO.File]::ReadAllBytes('%PT_EXE%'))).Replace('-',''); $b='https://github.com/%REPO%/releases/latest/download'; $obj=[ordered]@{ version=$ver; released=$rel; min_version='1.0.0.0'; downloads=[ordered]@{ Standalone=($b+'/LogViewer.exe'); Portable=($b+'/LogViewerPortable.exe') }; sha256=[ordered]@{ Standalone=$h1; Portable=$h2 } }; [IO.File]::WriteAllText($vj, ($obj | ConvertTo-Json -Depth 6), (New-Object Text.UTF8Encoding($false)))"
if errorlevel 1 ( echo [ERRO] Falhou a gerar o version.json. & pause & exit /b 1 )
echo        --- version.json ---
type "%VERSIONJSON%"
echo.
echo        --------------------
echo        OK

:: ── 10. GitHub Release ───────────────────────────────────────
:: Feita ANTES do push: se falhar aqui, o site e o ClickOnce ainda nao
:: foram enviados, por isso nada fica inconsistente para os utilizadores.
echo [10/11] A criar a Release v%NEWVER% no GitHub...
echo        ^(upload de 4 ficheiros, ~225 MB - pode demorar 2-5 min^)
gh release create "v%NEWVER%" ^
    "%SA_EXE%" ^
    "%SA_ZIP%" ^
    "%PT_EXE%" ^
    "%PT_ZIP%" ^
    --repo "%REPO%" ^
    --title "v%NEWVER%" ^
    --notes "Release v%NEWVER%. See landing page for installation options."
if errorlevel 1 (
    echo [ERRO] gh release create falhou.
    echo        Causas possiveis:
    echo          - sem ligacao a internet
    echo          - login expirado ^(corre 'gh auth status'^)
    echo          - upload interrompido
    echo        NOTA: o site ainda NAO foi enviado, nada ficou inconsistente.
    echo              Podes voltar a correr este script com a mesma versao.
    pause & exit /b 1
)
echo        OK
echo        URL: https://github.com/%REPO%/releases/tag/v%NEWVER%

:: ── 11. commit + push do repo dist ───────────────────────────
echo [11/11] git commit + push do repo dist...
cd /d "%DIST_DIR%"

:: Os binarios grandes vivem nas Releases, nunca no repo (o Portable tem
:: ~158 MB e o limite do GitHub sao 100 MB). O .gitignore ja os exclui, mas
:: se algum ficou tracked no historico tem de sair do indice.
if not exist ".gitignore" (
    echo        [AVISO] .gitignore nao encontrado - os binarios podem entrar no repo!
)
for %%F in (
    "StandAlone\LogViewer.exe"
    "StandAlone\LogViewer.zip"
    "Portable\LogViewer.exe"
    "Portable\LogViewerPortable.exe"
    "Portable\LogViewerPortable.zip"
) do (
    git ls-files --error-unmatch "%%~F" >nul 2>&1
    if not errorlevel 1 (
        git rm --cached "%%~F" >nul
        echo        git rm --cached: %%~F
    )
)

git add -A
git commit -m "Release v%NEWVER%"
if errorlevel 1 (
    echo        [AVISO] Nada para commit ^(repo ja sincronizado^). A tentar push na mesma...
) else (
    echo        Commit criado.
)
git push origin main
if errorlevel 1 ( echo [ERRO] git push falhou. Verifica 'git status' e o OneDrive. & pause & exit /b 1 )
echo        OK

echo.
echo ==========================================
:: O "!" precisa de CARET DUPLO: com EnableDelayedExpansion, tanto "!" como "^!"
:: sao consumidos pelo cmd; so "^^!" imprime o caracter.
echo   Publicado com sucesso^^!  v%NEWVER%
echo.
echo   Landing:  https://nunex-mbrothers.github.io/TheAbsoluteLogViewer/
echo   Release:  https://github.com/%REPO%/releases/tag/v%NEWVER%
echo.
echo   Edicoes:
echo     ClickOnce:  LogViewer.application + Application Files\  ^(no repo^)
echo     StandAlone: releases/latest/download/LogViewer.exe ^(+ .zip^)
echo     Portable:   releases/latest/download/LogViewerPortable.exe ^(+ .zip^)
echo.
echo   LEMBRETE: commita no repo PRIVADO ^(LogViewer^) o bump de versao:
echo     LogViewer.csproj              -^> %NEWVER%
echo     ClickOnceProfile.pubxml       -^> %NEWVER%
echo ==========================================
echo.
pause
