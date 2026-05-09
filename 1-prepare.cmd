@echo off
setlocal EnableDelayedExpansion

set "CSPROJ=%~dp0..\LogViewer\LogViewer.csproj"
set "PUBXML=%~dp0..\LogViewer\Properties\PublishProfiles\ClickOnceProfile.pubxml"
set "VERSIONJSON=%~dp0StandAlone\version.json"

echo.
echo ==========================================
echo   The Absolute LogViewer  --  Prepare
echo ==========================================
echo.

:: ── 1. Ler versao actual do .csproj ──────────────────────────
echo [1/6] A ler versao actual...
if not exist "%CSPROJ%" (
    echo [ERRO] Nao encontrou: %CSPROJ%
    pause & exit /b 1
)
for /f "tokens=*" %%a in ('findstr /r "<Version>[0-9]" "%CSPROJ%"') do set LINE=%%a
for /f "tokens=2 delims=><" %%b in ("%LINE%") do set CURRENT=%%b
echo       Versao actual: %CURRENT%
echo       OK

:: ── 2. Pedir e validar nova versao ────────────────────────────
echo [2/6] Nova versao (Enter para manter %CURRENT%):
set /p NEWVER=      Nova versao: 
if "%NEWVER%"=="" set NEWVER=%CURRENT%

:: Remover aspas eventuais que possam ter sido coladas
set NEWVER=%NEWVER:"=%

:: Validacao via PowerShell (regex robusta, ao contrario do findstr).
:: Tem de ser N.N.N.N (apenas digitos e 3 pontos).
powershell -NoProfile -Command "if ('%NEWVER%' -notmatch '^\d+\.\d+\.\d+\.\d+$') { exit 1 }"
if errorlevel 1 (
    echo [ERRO] Formato invalido: %NEWVER%
    echo        Tem de ser N.N.N.N como por exemplo 1.5.1.0
    pause
    exit /b 1
)
echo       Nova versao: %NEWVER%
echo       OK

:: ── 3. Actualizar .csproj ─────────────────────────────────────
echo [3/6] A actualizar LogViewer.csproj...
powershell -NoProfile -Command ^
    "$c = Get-Content '%CSPROJ%';" ^
    "$c = $c -replace '<Version>.*</Version>', '<Version>%NEWVER%</Version>';" ^
    "$c = $c -replace '<AssemblyVersion>.*</AssemblyVersion>', '<AssemblyVersion>%NEWVER%</AssemblyVersion>';" ^
    "$c = $c -replace '<FileVersion>.*</FileVersion>', '<FileVersion>%NEWVER%</FileVersion>';" ^
    "$c | Set-Content '%CSPROJ%'"
if %ERRORLEVEL% neq 0 (
    echo [ERRO] Falhou a actualizar o .csproj.
    pause & exit /b 1
)
echo       OK

:: ── 4. Actualizar .pubxml (ClickOnce) ─────────────────────────
echo [4/6] A actualizar ClickOnceProfile.pubxml...
if not exist "%PUBXML%" (
    for /r "%~dp0..\LogViewer" %%f in (ClickOnceProfile.pubxml) do set "PUBXML=%%f"
)
if not exist "%PUBXML%" (
    echo [ERRO] ClickOnceProfile.pubxml nao encontrado.
    pause & exit /b 1
)
powershell -NoProfile -Command ^
    "(Get-Content '%PUBXML%') -replace '<ApplicationVersion>.*</ApplicationVersion>', '<ApplicationVersion>%NEWVER%</ApplicationVersion>' | Set-Content '%PUBXML%'"
if %ERRORLEVEL% neq 0 (
    echo [ERRO] Falhou a actualizar o pubxml.
    pause & exit /b 1
)
echo       OK

:: ── 5. Actualizar version.json (gera do zero com schema novo) ─
echo [5/6] A gerar version.json...
:: Extrair pasta do path do version.json para validacao
for %%I in ("%VERSIONJSON%") do set "VERSIONJSON_DIR=%%~dpI"
if not exist "%VERSIONJSON_DIR%" (
    echo [ERRO] Pasta nao existe: %VERSIONJSON_DIR%
    echo        Cria a pasta StandAlone\ em LogViewer-dist\ antes de continuar.
    pause & exit /b 1
)

:: Skip se versao nao mudou e o ficheiro ja existe.
:: Razao: o version.json grava a "released" date, que so deve mudar
:: quando ha realmente uma nova versao. Re-correr o prepare para a
:: mesma versao nao deveria alterar a data publicamente registada.
if "%NEWVER%"=="%CURRENT%" (
    if exist "%VERSIONJSON%" (
        echo       Versao nao mudou e ficheiro existe - preservado.
        echo       OK
        goto :version_json_done
    )
)

:: Data ISO YYYY-MM-DD obtida via PowerShell (independente do locale)
for /f %%d in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd"') do set TODAY=%%d

:: Escrever o version.json do zero. Estrategia: gerar um .ps1 temporario
:: com o conteudo certo e executa-lo. Mais fiavel que regex ou echo dentro
:: de blocos batch (que sofrem com chavetas, aspas e parentesis).
set "TMPPS=%TEMP%\logviewer-write-version.ps1"
(
    echo $json = @"
    echo {
    echo     "version": "%NEWVER%",
    echo     "released": "%TODAY%",
    echo     "min_version": "1.0.0.0",
    echo     "downloads": ^{
    echo         "Standalone": "https://github.com/NuneX-mBrothers/TheAbsoluteLogViewer/releases/latest/download/LogViewer.exe",
    echo         "Portable":   "https://github.com/NuneX-mBrothers/TheAbsoluteLogViewer/releases/latest/download/LogViewerPortable.exe"
    echo     ^}
    echo ^}
    echo "@
    echo Set-Content -Path '%VERSIONJSON%' -Value $json -NoNewline
) > "%TMPPS%"

powershell -NoProfile -ExecutionPolicy Bypass -File "%TMPPS%"
if %ERRORLEVEL% neq 0 (
    del "%TMPPS%" 2>nul
    echo [ERRO] Falhou a escrever o version.json.
    pause & exit /b 1
)
del "%TMPPS%" 2>nul
echo       Data: %TODAY%
echo       OK

:version_json_done

:: ── 6. Copiar index.html + assets para LogViewer-dist\ ─────────
echo [6/6] A copiar index.html e assets para LogViewer-dist\...
set "DOCS_DIR=%~dp0..\LogViewer\docs"
set "DOCS_INDEX=%DOCS_DIR%\index.html"
set "DIST_INDEX=%~dp0index.html"

if not exist "%DOCS_INDEX%" (
    echo       [AVISO] %DOCS_INDEX% nao encontrado - ignorado.
) else (
    rem Copiar substituindo __VERSION__ pela versao actual.
    rem Usa PowerShell para replace fiavel (tolera UTF-8/BOM/qualquer charset).
    powershell -NoProfile -Command "(Get-Content -Raw '%DOCS_INDEX%') -replace '__VERSION__', '%NEWVER%' | Set-Content -NoNewline '%DIST_INDEX%'"
    if errorlevel 1 (
        echo [ERRO] Falhou a copiar/substituir index.html.
        pause & exit /b 1
    )
    echo       Copiado e versao injectada: index.html ^(v%NEWVER%^)
)

:: Copiar assets graficos (jpg, png, ico, etc.) que o index.html possa
:: referenciar. Mantem-se o docs\ como fonte unica de verdade.
for %%E in (jpg jpeg png gif svg ico webp) do (
    for %%F in ("%DOCS_DIR%\*.%%E") do (
        if exist "%%~F" (
            copy /Y "%%~F" "%~dp0" >nul
            echo       Copiado: %%~nxF
        )
    )
)
echo       OK

:: ── Limpeza: apagar publish anterior ──────────────────────────
echo.
echo A limpar bin\Release anterior...
set "BIN=C:\Users\nmend\OneDrive\My Code\LogViewer\LogViewer\bin\Release\net10.0-windows\win-x64"
if exist "%BIN%" (
    rmdir /s /q "%BIN%"
    echo       OK
) else (
    echo       (nao existe - ignorado)
)

echo.
echo ==========================================
echo   Pronto para publicar!
echo   Versao: %NEWVER%
echo   Data:   %TODAY%
echo.
echo   No Visual Studio, faz Publish dos 3
echo   profiles (ClickOnce, Standalone, Portable).
echo   Depois corre o 2-publish.cmd
echo ==========================================
echo.
pause
