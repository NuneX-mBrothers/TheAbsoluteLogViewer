@echo off
setlocal EnableDelayedExpansion

set "CSPROJ=%~dp0..\LogViewer\LogViewer.csproj"
set "PUBXML=%~dp0..\LogViewer\Properties\PublishProfiles\ClickOnceProfile.pubxml"
set "DOCS=%~dp0..\LogViewer\docs\index.html"

echo.
echo ==========================================
echo   The Absolute LogViewer  --  Prepare
echo ==========================================
echo.

:: ── 1. Ler versao actual do .csproj ──────────────────────────
echo [1/4] A ler versao actual...
if not exist "%CSPROJ%" (
    echo [ERRO] Nao encontrou: %CSPROJ%
    pause & exit /b 1
)
for /f "tokens=*" %%a in ('findstr /r "<Version>[0-9]" "%CSPROJ%"') do set LINE=%%a
for /f "tokens=2 delims=><" %%b in ("%LINE%") do set CURRENT=%%b
for /f "tokens=1,2,3 delims=." %%a in ("%CURRENT%") do (
    set MAJOR=%%a
    set MINOR=%%b
    set BUILD=%%c
)
echo       Versao actual: %CURRENT%
echo       OK




:: ── 2. Pedir nova versao ──────────────────────────────────────
echo [2/4] Nova versao (Enter para manter %CURRENT%):
set /p NEWVER=      Nova versao: 
if "%NEWVER%"=="" set NEWVER=%CURRENT%
for /f "tokens=1,2,3 delims=." %%a in ("%NEWVER%") do set VERSHOW=%%a.%%b.%%c
echo       Nova versao: %NEWVER%
echo       OK

:: ── 3. Actualizar .csproj ─────────────────────────────────────
echo [3/4] A actualizar LogViewer.csproj...
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

:: ── 4. Actualizar .pubxml ─────────────────────────────────────
echo [4/4] A actualizar ClickOnceProfile.pubxml...
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

:: ── 1 A. A apagar anterior publish em  ──────────────────────────
echo A Apagar a anterior distribuição "C:\Users\nmend\OneDrive\My Code\LogViewer\LogViewer\bin\Release\net10.0-windows\win-x64"
rmdir /s /q "C:\Users\nmend\OneDrive\My Code\LogViewer\LogViewer\bin\Release\net10.0-windows\win-x64"


echo.
echo ==========================================
echo   Pronto para publicar!
echo   Versao: %NEWVER%
echo.
echo   Faz agora o Publish no Visual Studio
echo   e depois corre o 2-publish.cmd
echo ==========================================
echo.
pause
