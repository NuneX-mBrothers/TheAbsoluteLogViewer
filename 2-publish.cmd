@echo off
setlocal EnableDelayedExpansion

set "DIST_DIR=%~dp0"
set "CSPROJ=%~dp0..\LogViewer\LogViewer.csproj"

set "STANDALONE_DIR=%~dp0StandAlone"
set "STANDALONE_EXE=%STANDALONE_DIR%\LogViewer.exe"
set "STANDALONE_ZIP=%STANDALONE_DIR%\LogViewer.zip"

set "PORTABLE_DIR=%~dp0Portable"
set "PORTABLE_RAW_EXE=%PORTABLE_DIR%\LogViewer.exe"
set "PORTABLE_FINAL_EXE=%PORTABLE_DIR%\LogViewerPortable.exe"
set "PORTABLE_PDB=%PORTABLE_DIR%\LogViewer.pdb"
set "PORTABLE_ZIP=%PORTABLE_DIR%\LogViewerPortable.zip"

set "REPO=NuneX-mBrothers/TheAbsoluteLogViewer"

echo.
echo ==========================================
echo   The Absolute LogViewer  --  Publish
echo ==========================================
echo.

:: ── 1. Ler versao do .csproj ──────────────────────────────────
echo [1/8] A ler versao do LogViewer.csproj...
if not exist "%CSPROJ%" (
    echo [ERRO] Nao encontrou: %CSPROJ%
    pause & exit /b 1
)
for /f "tokens=*" %%a in ('findstr /r /c:"<Version>[0-9][0-9.]*</Version>" "%CSPROJ%"') do set LINE=%%a
for /f "tokens=2 delims=><" %%b in ("%LINE%") do set VERSION=%%b
if "%VERSION%"=="" (
    echo [ERRO] Nao foi possivel ler a versao.
    pause & exit /b 1
)
echo       Versao: %VERSION%
echo       OK

:: ── 2. Validar Standalone ─────────────────────────────────────
echo [2/8] A validar Standalone...
if not exist "%STANDALONE_EXE%" (
    echo [ERRO] Nao encontrou %STANDALONE_EXE%
    echo        Faz Publish do Standalone no Visual Studio antes de continuar.
    pause & exit /b 1
)
echo       OK: %STANDALONE_EXE%

:: ── 3. Validar Portable ───────────────────────────────────────
echo [3/8] A validar Portable...
if not exist "%PORTABLE_RAW_EXE%" (
    if not exist "%PORTABLE_FINAL_EXE%" (
        echo [ERRO] Nao encontrou Portable .exe em %PORTABLE_DIR%
        echo        Faz Publish do Portable no Visual Studio antes de continuar.
        pause & exit /b 1
    )
)
echo       OK

:: ── 4. Standalone: apagar zip antigo + criar novo ─────────────
echo [4/8] A preparar Standalone (zip)...
if exist "%STANDALONE_ZIP%" (
    del "%STANDALONE_ZIP%"
    echo       Apagado: LogViewer.zip antigo
)
powershell -NoProfile -Command "Compress-Archive -Path '%STANDALONE_EXE%' -DestinationPath '%STANDALONE_ZIP%' -Force"
if errorlevel 1 (
    echo [ERRO] Falhou a criar Standalone zip.
    pause & exit /b 1
)
echo       Criado: LogViewer.zip
echo       OK

:: ── 5. Portable: limpar antigos, renomear, criar zip ──────────
echo [5/8] A preparar Portable (rename + clean + zip)...

rem 5a. Apagar .pdb (debug symbols, nao distribuir)
if exist "%PORTABLE_PDB%" (
    del "%PORTABLE_PDB%"
    echo       Apagado: LogViewer.pdb
)

rem 5b. Apagar zip antigo se existe
if exist "%PORTABLE_ZIP%" (
    del "%PORTABLE_ZIP%"
    echo       Apagado: LogViewerPortable.zip antigo
)

rem 5c. Apagar versao final antiga se existe (caso de re-run)
if exist "%PORTABLE_FINAL_EXE%" (
    del "%PORTABLE_FINAL_EXE%"
    echo       Apagado: LogViewerPortable.exe antigo
)

rem 5d. Renomear LogViewer.exe -> LogViewerPortable.exe
if exist "%PORTABLE_RAW_EXE%" (
    ren "%PORTABLE_RAW_EXE%" "LogViewerPortable.exe"
    echo       Renomeado: LogViewer.exe -^> LogViewerPortable.exe
)

rem 5e. Validar resultado
if not exist "%PORTABLE_FINAL_EXE%" (
    echo [ERRO] LogViewerPortable.exe nao existe apos rename.
    pause & exit /b 1
)

rem 5f. Criar zip
powershell -NoProfile -Command "Compress-Archive -Path '%PORTABLE_FINAL_EXE%' -DestinationPath '%PORTABLE_ZIP%' -Force"
if errorlevel 1 (
    echo [ERRO] Falhou a criar Portable zip.
    pause & exit /b 1
)
echo       Criado: LogViewerPortable.zip
echo       OK

:: ── 6. Criar release no GitHub ────────────────────────────────
echo [6/8] A criar release v%VERSION% no GitHub...
echo       (upload de 4 ficheiros, ~225 MB total - pode demorar 2-5 min)

gh release create "v%VERSION%" ^
    "%STANDALONE_EXE%" ^
    "%STANDALONE_ZIP%" ^
    "%PORTABLE_FINAL_EXE%" ^
    "%PORTABLE_ZIP%" ^
    --repo "%REPO%" ^
    --title "v%VERSION%" ^
    --notes "Release v%VERSION%. See landing page for installation options."
if errorlevel 1 (
    echo [ERRO] gh release create falhou.
    echo        Causas possiveis:
    echo          - tag v%VERSION% ja existe ^(usa 'gh release delete v%VERSION%' primeiro^)
    echo          - login expirado ^(corre 'gh auth status'^)
    echo          - sem ligacao a internet
    pause & exit /b 1
)
echo       OK
echo       URL: https://github.com/%REPO%/releases/tag/v%VERSION%

:: ── 7. Limpar repo dos binarios grandes ───────────────────────
echo [7/8] A limpar binarios grandes do repo...
cd /d "%DIST_DIR%"

rem .gitignore deve impedir que sejam adicionados, mas se ja estiverem
rem tracked no historico do git temos de os remover do indice.
rem Os binarios vivem agora em GitHub Releases.
if not exist ".gitignore" (
    echo       [AVISO] .gitignore nao encontrado em %DIST_DIR%
    echo               Os binarios podem nao estar a ser ignorados!
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
        echo       git rm --cached: %%~F
    )
)
echo       OK

:: ── 8. git add + commit + push ────────────────────────────────
echo [8/8] git commit + push...
git add -A
git commit -m "Release v%VERSION%"
if errorlevel 1 (
    echo       [AVISO] Nada para commit ^(sem alteracoes nos ficheiros do repo^)
) else (
    echo       Commit criado.
)

git push origin main
if errorlevel 1 (
    echo [ERRO] git push falhou.
    pause & exit /b 1
)
echo       OK

echo.
echo ==========================================
echo   Publicado com sucesso!
echo   v%VERSION%
echo.
echo   Landing:  https://nunex-mbrothers.github.io/TheAbsoluteLogViewer/
echo   Release:  https://github.com/%REPO%/releases/tag/v%VERSION%
echo ==========================================
echo.
pause
