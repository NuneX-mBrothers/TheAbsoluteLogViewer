@echo off
setlocal EnableDelayedExpansion

set "DIST_DIR=%~dp0"
set "CSPROJ=%~dp0..\LogViewer\LogViewer.csproj"
set "PUBXML=%~dp0..\LogViewer\Properties\PublishProfiles\ClickOnceProfile.pubxml"
set "DOCS=%~dp0..\LogViewer\docs\index.html"

echo.
echo ==========================================
echo   The Absolute LogViewer  --  Git Push
echo ==========================================
echo.

:: ── 1. Ler versao do .csproj ──────────────────────────────────
echo [1/6] A ler versao do LogViewer.csproj...
if not exist "%CSPROJ%" (
    echo [ERRO] Nao encontrou: %CSPROJ%
    pause & exit /b 1
)
for /f "tokens=*" %%a in ('findstr /r "<Version>[0-9]" "%CSPROJ%"') do set LINE=%%a
for /f "tokens=2 delims=><" %%b in ("%LINE%") do set VERSION=%%b
for /f "tokens=1,2,3 delims=." %%a in ("%VERSION%") do set VERSHOW=%%a.%%b.%%c
if "%VERSION%"=="" (
    echo [ERRO] Nao foi possivel ler a versao.
    pause & exit /b 1
)
echo       Versao: %VERSION%
echo       OK

:: ── 2. Localizar e actualizar o .pubxml ───────────────────────
echo [2/6] A localizar ClickOnceProfile.pubxml...
if not exist "%PUBXML%" (
    echo       Nao encontrou em Properties\ - a pesquisar...
    for /r "%~dp0..\LogViewer" %%f in (ClickOnceProfile.pubxml) do set "PUBXML=%%f"
)
if not exist "%PUBXML%" (
    echo [ERRO] ClickOnceProfile.pubxml nao encontrado.
    pause & exit /b 1
)
echo       Encontrado: %PUBXML%
powershell -NoProfile -Command ^
    "(Get-Content -Path '%PUBXML%') -replace '<ApplicationVersion>.*</ApplicationVersion>', '<ApplicationVersion>%VERSION%</ApplicationVersion>' | Set-Content -Path '%PUBXML%'"
if %ERRORLEVEL% neq 0 (
    echo [ERRO] Falhou a actualizar o pubxml.
    pause & exit /b 1
)
echo       OK

:: ── 3. Actualizar versao no index.html ───────────────────────
echo [3/6] A actualizar index.html para v%VERSHOW%...
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

:: ── 4. git add ────────────────────────────────────────────────
echo [4/6] git add...
cd /d "%DIST_DIR%"
git add -A
if %ERRORLEVEL% neq 0 (
    echo [ERRO] git add falhou.
    pause & exit /b 1
)
echo       OK

:: ── 5. git commit ─────────────────────────────────────────────
echo [5/6] git commit...
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
