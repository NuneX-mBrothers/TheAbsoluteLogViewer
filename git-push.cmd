@echo off
setlocal EnableDelayedExpansion

set "DIST_DIR=%~dp0"
set "CSPROJ=%~dp0..\LogViewer\LogViewer.csproj"
set "DOCS=%~dp0..\LogViewer\docs\index.html"

:: Le versao do .csproj
for /f "tokens=*" %%a in ('findstr /r "<Version>[0-9]" "%CSPROJ%"') do set LINE=%%a
for /f "tokens=2 delims=><" %%b in ("%LINE%") do set VERSION=%%b
for /f "tokens=1,2,3 delims=." %%a in ("%VERSION%") do set VERSHOW=%%a.%%b.%%c

echo.
echo ==========================================
echo   The Absolute LogViewer
echo   Git Push  --  v%VERSION%
echo ==========================================
echo.

:: Verifica se o index.html existe
if not exist "%DOCS%" (
    echo [ERRO] Nao encontrou: %DOCS%
    pause
    exit /b 1
)

:: Actualiza versao no index.html via PowerShell e copia para dist
echo Actualizando index.html para v%VERSHOW%...
powershell -NoProfile -Command "(Get-Content -Path '%DOCS%') -replace 'v[0-9]+\.[0-9]+\.[0-9]+', 'v%VERSHOW%' | Set-Content -Path '%DIST_DIR%index.html'"
if %ERRORLEVEL% neq 0 (
    echo [ERRO] PowerShell falhou.
    pause
    exit /b 1
)
echo OK

cd /d "%DIST_DIR%"

echo [1/3] git add...
git add -A

echo [2/3] git commit...
git commit -m "Release v%VERSION%"

echo [3/3] git push...
git push origin main

if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERRO] Push falhou.
    pause
    exit /b 1
)

echo.
echo ==========================================
echo   Publicado com sucesso!
echo   https://nunex-mbrothers.github.io/TheAbsoluteLogViewer/
echo ==========================================
echo.
pause
