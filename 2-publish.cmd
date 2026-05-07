@echo off
setlocal EnableDelayedExpansion

set "DIST_DIR=%~dp0"
set "CSPROJ=%~dp0..\LogViewer\LogViewer.csproj"
set "DOCS=%~dp0..\LogViewer\docs\index.html"
set "STANDALONE_DIR=%~dp0StandAlone"
set "STANDALONE_EXE=%STANDALONE_DIR%\LogViewer.exe"
set "VERSION_JSON=%STANDALONE_DIR%\version.json"

echo.
echo ==========================================
echo   The Absolute LogViewer  --  Publish
echo ==========================================
echo.

:: ── 1. Ler versao do .csproj ──────────────────────────────────
echo [1/6] A ler versao do LogViewer.csproj...
if not exist "%CSPROJ%" (
    echo [ERRO] Nao encontrou: %CSPROJ%
    pause & exit /b 1
)
for /f "tokens=*" %%a in ('findstr /r /c:"<Version>[0-9][0-9.]*</Version>" "%CSPROJ%"') do set LINE=%%a
for /f "tokens=2 delims=><" %%b in ("%LINE%") do set VERSION=%%b
for /f "tokens=1,2,3 delims=." %%a in ("%VERSION%") do set VERSHOW=%%a.%%b.%%c
if "%VERSION%"=="" (
    echo [ERRO] Nao foi possivel ler a versao.
    pause & exit /b 1
)
echo       Versao: %VERSION%
echo       OK

:: ── 2. Actualizar versao no index.html ───────────────────────
echo [2/6] A actualizar index.html para v%VERSHOW%...
if not exist "%DOCS%" (
    echo       [AVISO] docs\index.html nao encontrado - ignorado.
) else (
    powershell -NoProfile -Command ^
        "(Get-Content -Path '%DOCS%') -replace 'v[0-9]+\.[0-9]+\.[0-9]+', 'v%VERSHOW%' | Set-Content -Path '%DIST_DIR%index.html'"
    if %ERRORLEVEL% neq 0 (
        echo [ERRO] Falhou a actualizar o index.html.
        pause & exit /b 1
    )
    echo       OK
)

:: ── 3. Validar .exe standalone ────────────────────────────────
echo [3/6] A validar .exe standalone...
if not exist "%STANDALONE_EXE%" (
    echo       [AVISO] %STANDALONE_EXE% nao encontrado.
    echo       Faz Publish standalone no Visual Studio antes de continuar,
    echo       ou ignora este passo se so estas a publicar ClickOnce.
    echo.
    set /p "SKIP_STANDALONE=      Continuar sem actualizar standalone [S/N]? "
    if /i not "!SKIP_STANDALONE!"=="S" (
        echo Cancelado pelo utilizador.
        pause & exit /b 1
    )
    set "STANDALONE_OK=0"
    echo       Standalone IGNORADO.
) else (
    set "STANDALONE_OK=1"
    echo       Encontrado: %STANDALONE_EXE%

    rem ── Limpeza: o Publish single-file deixa .pdb ao lado do .exe.
    rem    Apagamos extensoes nao desejadas (mantendo LogViewer.exe e
    rem    version.json intactos). del aceita wildcards e e idempotente.
    if exist "%STANDALONE_DIR%\*.pdb"               del /q "%STANDALONE_DIR%\*.pdb"
    if exist "%STANDALONE_DIR%\*.xml"               del /q "%STANDALONE_DIR%\*.xml"
    if exist "%STANDALONE_DIR%\*.deps.json"         del /q "%STANDALONE_DIR%\*.deps.json"
    if exist "%STANDALONE_DIR%\*.runtimeconfig.json" del /q "%STANDALONE_DIR%\*.runtimeconfig.json"

    echo       OK
)

:: ── 4. Gerar version.json (so se o .exe existe) ───────────────
echo [4/6] A gerar version.json...
if "%STANDALONE_OK%"=="0" (
    echo       Ignorado - sem .exe standalone para anunciar.
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "$today = Get-Date -Format 'yyyy-MM-dd';" ^
        "$obj = [ordered]@{" ^
        "  version    = '%VERSION%';" ^
        "  url        = 'https://nunex-mbrothers.github.io/TheAbsoluteLogViewer/StandAlone/LogViewer.exe';" ^
        "  released   = $today;" ^
        "  min_version= '1.0.0.0'" ^
        "};" ^
        "$obj | ConvertTo-Json | Set-Content -Path '%VERSION_JSON%' -Encoding UTF8"
    if %ERRORLEVEL% neq 0 (
        echo [ERRO] Falhou a gerar version.json.
        pause & exit /b 1
    )
    echo       Gerado: %VERSION_JSON%
    echo       OK
)

:: ── 5. git add + commit ───────────────────────────────────────
echo [5/6] git add + commit...
cd /d "%DIST_DIR%"
git add -A
if %ERRORLEVEL% neq 0 (
    echo [ERRO] git add falhou.
    pause & exit /b 1
)
git commit -m "Release v%VERSION%"
if %ERRORLEVEL% neq 0 (
    echo       [AVISO] Nada para fazer commit - ficheiros identicos?
) else (
    echo       OK
)

:: ── 6. git push ───────────────────────────────────────────────
echo [6/6] git push para GitHub...
git push origin main
if %ERRORLEVEL% neq 0 (
    echo [ERRO] Push falhou. Verifica a ligacao ao GitHub.
    pause & exit /b 1
)
echo       OK

echo.
echo ==========================================
echo   Publicado com sucesso!
echo   v%VERSION%
echo   https://nunex-mbrothers.github.io/TheAbsoluteLogViewer/
echo ==========================================
echo.
pause
