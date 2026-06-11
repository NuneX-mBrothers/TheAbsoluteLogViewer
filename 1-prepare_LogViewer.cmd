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
echo [1/8] A ler versao actual...
if not exist "%CSPROJ%" (
    echo [ERRO] Nao encontrou: %CSPROJ%
    pause & exit /b 1
)
for /f "tokens=*" %%a in ('findstr /r "<Version>[0-9]" "%CSPROJ%"') do set LINE=%%a
for /f "tokens=2 delims=><" %%b in ("%LINE%") do set CURRENT=%%b
echo       Versao actual: %CURRENT%
echo       OK

:: ── 2. Pedir e validar nova versao ────────────────────────────
echo [2/8] Nova versao (Enter para manter %CURRENT%):
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
echo [3/8] A actualizar LogViewer.csproj...
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
echo [4/8] A actualizar ClickOnceProfile.pubxml...
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
echo [5/8] A gerar version.json...
:: Extrair pasta do path do version.json para validacao
for %%I in ("%VERSIONJSON%") do set "VERSIONJSON_DIR=%%~dpI"
if not exist "%VERSIONJSON_DIR%" (
    echo [ERRO] Pasta nao existe: %VERSIONJSON_DIR%
    echo        Cria a pasta StandAlone\ em LogViewer-dist\ antes de continuar.
    pause & exit /b 1
)

:: Skip se versao no version.json ja for a desejada.
:: Razao: o version.json grava a "released" date, que so deve mudar
:: quando ha realmente uma nova versao publicada. Re-correr o prepare
:: para a mesma versao nao deveria alterar a data publicamente registada.
::
:: CRITICO: comparar com a versao REAL no version.json (nao com %CURRENT%
:: que vem do .csproj). Se o .csproj e o version.json estiverem fora de
:: sync (ex: alguem edita o .csproj a mao primeiro), a comparacao com
:: %CURRENT% leva a skip indevido e o version.json fica desactualizado
:: -- causando "ja tens a ultima versao" para todos os utilizadores.
if exist "%VERSIONJSON%" (
    for /f "tokens=2 delims=:," %%v in ('findstr /c:"\"version\"" "%VERSIONJSON%"') do (
        set "JSONVER=%%v"
    )
    set "JSONVER=!JSONVER: =!"
    set "JSONVER=!JSONVER:"=!"
    if "!JSONVER!"=="%NEWVER%" (
        for /f "tokens=2 delims=:," %%r in ('findstr /c:"\"released\"" "%VERSIONJSON%"') do (
            set "JSONDATE=%%r"
        )
        set "JSONDATE=!JSONDATE: =!"
        set "JSONDATE=!JSONDATE:"=!"
        echo       version.json ja esta em %NEWVER% ^(released=!JSONDATE!^) - preservado.
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

:: ── 6. Copiar o SITE (docs\ inteiro) para LogViewer-dist\ ──────
echo [6/8] A copiar o site ^(docs\^) para LogViewer-dist\...
set "DOCS_DIR=%~dp0..\LogViewer\docs"
set "DIST_INDEX=%~dp0index.html"

if not exist "%DOCS_DIR%\index.html" (
    echo [ERRO] %DOCS_DIR%\index.html nao encontrado.
    pause & exit /b 1
)

:: Copia recursiva da pasta docs\ (index.html + css\ js\ i18n\ assets\ +
:: screenshots) para a raiz do dist, preservando a estrutura. /E inclui
:: subpastas; SEM /MIR para nao apagar nada do que ja existe no dist (os
:: ficheiros ClickOnce, StandAlone\, Portable\ ficam intactos). /XF exclui
:: os backups __index*.html da pasta docs.
robocopy "%DOCS_DIR%" "%~dp0." /E /XF "__*.html" /R:2 /W:1 /NFL /NDL /NJH /NJS /NP >nul
:: robocopy: codigos de saida 0-7 = sucesso; >=8 = erro real.
if errorlevel 8 (
    echo [ERRO] robocopy falhou a copiar o site para o dist.
    pause & exit /b 1
)

:: Injectar a versao no index.html copiado (substitui __VERSION__, incl. JSON-LD).
powershell -NoProfile -Command "(Get-Content -Raw '%DIST_INDEX%') -replace '__VERSION__', '%NEWVER%' | Set-Content -NoNewline '%DIST_INDEX%'"
if errorlevel 1 (
    echo [ERRO] Falhou a injectar a versao no index.html.
    pause & exit /b 1
)
echo       Site copiado ^(css/js/i18n/assets^) + versao injectada: v%NEWVER%
echo       OK

:: ── 7. Limpeza: apagar artefactos de build anteriores ────────
:: Forca rebuild fresco. Apaga bin\Release\ inteiro e obj\.
:: Preserva bin\Debug\ para nao interferir com F5.
echo [7/8] A limpar artefactos de build anteriores...
set "BIN=%~dp0..\LogViewer\bin\Release"
set "OBJ=%~dp0..\LogViewer\obj"

if exist "%BIN%" (
    rmdir /s /q "%BIN%"
    echo       Apagado: bin\Release\
) else (
    echo       (bin\Release nao existe - ignorado)
)

if exist "%OBJ%" (
    rmdir /s /q "%OBJ%"
    echo       Apagado: obj\
) else (
    echo       (obj\ nao existe - ignorado)
)
echo       OK

:: ── 8. Build das 3 edicoes (substitui o Publish manual no VS) ─
:: StandAlone e Portable: dotnet publish com propriedades explicitas.
:: ClickOnce: TEM de ser o MSBuild do Visual Studio (dotnet publish nao
:: suporta o protocolo ClickOnce). Gera para app.publish e copia-se o
:: deployment (LogViewer.application + setup.exe + Application Files\)
:: para a raiz do repo dist, replicando o que a UI do VS faz.
:: Ordem: StandAlone -> ClickOnce -> Portable. As duas primeiras sao
:: framework-dependent; a Portable (self-contained) fica para o fim
:: para nao contaminar o bin\ partilhado das outras.
echo [8/8] A compilar as 3 edicoes...

set "PROJ=%~dp0..\LogViewer\LogViewer.csproj"
set "SA_DIR=%~dp0StandAlone"
set "PT_DIR=%~dp0Portable"
set "APPPUB=%~dp0..\LogViewer\bin\Release\net10.0-windows\win-x64\app.publish"

:: Localizar o MSBuild.exe do Visual Studio (necessario para ClickOnce).
:: vswhere e chamado DIRETAMENTE (chamar dentro de um for /f rebenta
:: porque o caminho "C:\Program Files (x86)\..." tem espacos e o for /f
:: retira as aspas exteriores). Saida -> ficheiro temp -> set /p.
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
set "MSBUILD="
set "MSBTMP=%TEMP%\_lv_msbuild.txt"
if exist "%VSWHERE%" (
    "%VSWHERE%" -latest -prerelease -find "MSBuild\**\Bin\MSBuild.exe" > "%MSBTMP%" 2>nul
    set /p MSBUILD=<"%MSBTMP%"
    del "%MSBTMP%" 2>nul
)
if not defined MSBUILD (
    echo [ERRO] MSBuild do Visual Studio nao encontrado.
    echo        Necessario para publicar o ClickOnce.
    pause & exit /b 1
)

echo       - restore...
dotnet restore "%PROJ%" >nul
if errorlevel 1 ( echo [ERRO] dotnet restore falhou. & pause & exit /b 1 )

echo       - StandAlone ^(single-file, framework-dependent^)...
dotnet publish "%PROJ%" -c Release -p:PublishSingleFile=true -p:SelfContained=false -p:RuntimeIdentifier=win-x64 -p:IncludeNativeLibrariesForSelfExtract=true -p:IncludeAllContentForSelfExtract=true -p:DebugType=none -p:DebugSymbols=false -p:PublishDir="%SA_DIR%\\" --nologo -v minimal
if errorlevel 1 ( echo [ERRO] build StandAlone falhou. & pause & exit /b 1 )
echo         OK: %SA_DIR%\LogViewer.exe

echo       - ClickOnce ^(MSBuild^)...
"%MSBUILD%" "%PROJ%" /t:Publish /p:PublishProfile=ClickOnceProfile /p:Configuration=Release /restore /v:minimal /nologo
if errorlevel 1 ( echo [ERRO] build ClickOnce falhou. & pause & exit /b 1 )
if not exist "%APPPUB%\LogViewer.application" (
    echo [ERRO] ClickOnce: nao gerou app.publish em:
    echo        %APPPUB%
    pause & exit /b 1
)
echo         A copiar deployment ClickOnce para o repo dist...
copy /Y "%APPPUB%\LogViewer.application" "%~dp0" >nul
copy /Y "%APPPUB%\setup.exe" "%~dp0" >nul
xcopy /E /I /Y "%APPPUB%\Application Files" "%~dp0Application Files" >nul
if errorlevel 1 ( echo [ERRO] falhou a copiar os ficheiros ClickOnce. & pause & exit /b 1 )
echo         OK: LogViewer.application + setup.exe + Application Files\

echo       - Portable ^(single-file, self-contained, ReadyToRun - pode demorar 1-2 min^)...
dotnet publish "%PROJ%" -c Release -p:PublishSingleFile=true -p:SelfContained=true -p:RuntimeIdentifier=win-x64 -p:IncludeNativeLibrariesForSelfExtract=true -p:PublishReadyToRun=true -p:DebugType=none -p:DebugSymbols=false -p:PublishDir="%PT_DIR%\\" --nologo -v minimal
if errorlevel 1 ( echo [ERRO] build Portable falhou. & pause & exit /b 1 )
echo         OK: %PT_DIR%\LogViewer.exe

:: ── SHA-256 das edicoes -> version.json (integridade no auto-update) ──
:: O UpdateService verifica este hash no .exe descarregado antes de instalar.
:: Gera um .ps1 temporario (linhas via echo, sem bloco () para nao confundir o
:: parser do cmd) e corre-o. Usa .NET (SHA256/WriteAllText) para nao depender de
:: Get-FileHash e gravar sem BOM. Escreve os hashes no version.json do passo [5].
echo       - SHA-256: a calcular e gravar no version.json...
set "HASHPS=%TEMP%\logviewer-hash-version.ps1"
echo param($vjson,$f1,$f2) > "%HASHPS%"
echo $o = Get-Content $vjson -Raw ^| ConvertFrom-Json >> "%HASHPS%"
echo $sha = [System.Security.Cryptography.SHA256]::Create() >> "%HASHPS%"
echo $h1 = [BitConverter]::ToString($sha.ComputeHash([IO.File]::ReadAllBytes($f1))).Replace('-','') >> "%HASHPS%"
echo $h2 = [BitConverter]::ToString($sha.ComputeHash([IO.File]::ReadAllBytes($f2))).Replace('-','') >> "%HASHPS%"
echo $o ^| Add-Member -NotePropertyName sha256 -NotePropertyValue ([ordered]@{ Standalone = $h1; Portable = $h2 }) -Force >> "%HASHPS%"
echo $json = $o ^| ConvertTo-Json -Depth 6 >> "%HASHPS%"
echo [IO.File]::WriteAllText($vjson, $json, (New-Object Text.UTF8Encoding $false)) >> "%HASHPS%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%HASHPS%" "%VERSIONJSON%" "%SA_DIR%\LogViewer.exe" "%PT_DIR%\LogViewer.exe"
if errorlevel 1 ( echo [ERRO] falhou a gravar SHA-256 no version.json. & del "%HASHPS%" 2^>nul & pause & exit /b 1 )
del "%HASHPS%" 2>nul
echo         OK: SHA-256 escrito no version.json
echo       OK

echo.
echo ==========================================
echo   Build completo das 3 edicoes!
echo   Versao: %NEWVER%
if defined TODAY (
    echo   Data:   %TODAY%
) else (
    echo   Data:   ^(version.json preservado - data nao alterada^)
)
echo.
echo   --- version.json gerado ---
type "%VERSIONJSON%"
echo.
echo   ---------------------------
echo.
echo   StandAlone: StandAlone\LogViewer.exe
echo   Portable:   Portable\LogViewer.exe
echo   ClickOnce:  LogViewer.application + Application Files\
echo.
echo   Ja NAO precisas do Visual Studio.
echo   Agora corre o 2-publish_LogViewer.cmd
echo   ^(zips + GitHub Release + git push^).
echo ==========================================
echo.
pause
