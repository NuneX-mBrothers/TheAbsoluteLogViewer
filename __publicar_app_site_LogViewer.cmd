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
::   5) escreve a versao no index.html (o site E esta pasta -- nao ha copia)
::   6) para a app, limpa bin\Release + obj
::   7) compila as 3 edicoes: StandAlone -> ClickOnce -> Portable
::   8) renomeia o Portable, ASSINA os 2 exes e cria os .zip
::      (assinar altera os bytes: tem de ser antes dos .zip e dos hashes)
::   9) gera o version.json (versao + data + SHA-256) p/ o auto-update
:: 10) cria a Release em rascunho, sobe os 4 ficheiros UM A UM e publica-a
::  11) commit + push do repo dist (site + ClickOnce + version.json)
::  12) avisa o Bing pelo IndexNow (nao aborta: o site ja esta no ar)
::
::  O codigo e PRIVADO (repo LogViewer) e NAO e tocado por este script
::  alem do bump de versao -- esse commit e teu, ver o lembrete no fim.
::  Os binarios grandes vivem nas Releases, nunca no repo.
::  Para mudar SO o site (textos/traducoes), usa __publicar_site_LogViewer.cmd.
:: ════════════════════════════════════════════════════════════════════

set "DIST_DIR=%~dp0"
set "PROJ_DIR=%~dp0..\LogViewer"
set "PROJ=%PROJ_DIR%\LogViewer.csproj"
set "PUBXML=%PROJ_DIR%\Properties\PublishProfiles\ClickOnceProfile.pubxml"
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

:: ── Assinatura de codigo (Authenticode) ──────────────────────
:: O certificado e o MESMO do ExplorerFocus -- um certificado assina quantos
:: produtos se quiser. Escolhe-se pela IMPRESSAO DIGITAL e nunca pelo nome: o
:: /n do signtool casa por TEXTO, e um certificado parecido na loja da-lhe
:: "nao encontrado" ou, pior, assina com o errado.
::
:: O INTERRUPTOR: com LV_SIGN_SHA1 vazio o passo nao faz nada e a publicacao
:: corre como antes. Para publicar sem assinar, APAGA-SE o valor -- nao se
:: comenta a linha, para nao ficar meio-ligado.
::
:: NAO ha assinatura desassistida: a chave vive num cartao virtual servido
:: pelo SimplySign Desktop, que tem de estar A CORRER e com sessao aberta. O
:: signtool PARA a pedir o PIN. E desenho da Certum, nao defeito do script.
::
:: O que NAO e assinado, e porque: o ClickOnce fica de fora por decisao do
:: autor (2026-08-18) -- "se esta a funcionar, ninguem lhe mexe". Trocar-lhe o
:: certificado dos manifestos mudaria a IDENTIDADE da aplicacao e deixaria
:: quem ja a tem instalada sem actualizacoes, obrigando a reinstalar.
set "LV_SIGN_SHA1=7B04B8346ED85BF3D3D40D0791083233C9FFB4EF"
set "LV_SIGN_TS=http://time.certum.pl"

:: Como o VSWHERE acima: expandido AQUI, fora de qualquer bloco ( ... ), porque
:: o ")" de "(x86)" fecharia o bloco e o cmd rebentava.
set "WK10BIN=%ProgramFiles(x86)%\Windows Kits\10\bin"
set "SIGNTOOL=%WK10BIN%\10.0.26100.0\x64\signtool.exe"

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
echo [1/12]Verificacoes previas...

if not exist "%PROJ%"  ( echo [ERRO] Nao encontrou: %PROJ%  & pause & exit /b 1 )
if not exist "%PUBXML%" (
    for /r "%PROJ_DIR%" %%f in (ClickOnceProfile.pubxml) do set "PUBXML=%%f"
)
if not exist "%PUBXML%" ( echo [ERRO] ClickOnceProfile.pubxml nao encontrado. & pause & exit /b 1 )
if not exist "%DIST_INDEX%" ( echo [ERRO] Nao encontrou o site: %DIST_INDEX% & pause & exit /b 1 )
if not exist "%SA_DIR%" ( echo [ERRO] Falta a pasta StandAlone\ em %DIST_DIR% & pause & exit /b 1 )

where dotnet >nul 2>&1
if errorlevel 1 ( echo [ERRO] 'dotnet' nao esta no PATH. Instala o .NET SDK 10. & pause & exit /b 1 )

where gh >nul 2>&1
if errorlevel 1 ( echo [ERRO] 'gh' nao esta no PATH. Instala o GitHub CLI. & pause & exit /b 1 )

gh auth status >nul 2>&1
if errorlevel 1 ( echo [ERRO] 'gh' sem login. Corre 'gh auth login'. & pause & exit /b 1 )

:: Assinatura: verificar AGORA que o signtool existe. Descobri-lo so no passo
:: [8], ja depois de compiladas as tres edicoes, seria descobri-lo tarde.
::
:: Escrito com GOTO e sem blocos ( ... ) de proposito: o caminho contem
:: %ProgramFiles(x86)%, e o ")" desse nome fecha qualquer bloco onde apareca --
:: e a armadilha que ja esta documentada no cabecalho deste ficheiro.
if not defined LV_SIGN_SHA1 goto :sign_off
if exist "%SIGNTOOL%" goto :sign_ok

echo        signtool nao esta no caminho previsto; a procurar no Windows Kits...
set "SIGNTOOL="
for /f "delims=" %%s in ('dir /b /s "%WK10BIN%\signtool.exe" 2^>nul ^| findstr /i "\\x64\\"') do set "SIGNTOOL=%%s"
if not defined SIGNTOOL goto :sign_sem_signtool
if not exist "!SIGNTOOL!" goto :sign_sem_signtool
set "SIGNTOOL=!SIGNTOOL!"

:sign_ok
echo        Assinatura: ON  ^(cert %LV_SIGN_SHA1:~0,8%...^)
echo        signtool: %SIGNTOOL%
:: NAO usar ">" aqui: mesmo escapado, o cmd trata-o como redireccao e cria um
:: ficheiro com o nome da palavra seguinte. Ja aconteceu neste ficheiro.
echo        ** O SimplySign Desktop tem de estar ABERTO e com sessao iniciada,
echo           senao a assinatura para a pedir credenciais.
goto :sign_check_fim

:sign_sem_signtool
echo [ERRO] LV_SIGN_SHA1 esta definido mas nao ha signtool.exe nesta maquina.
echo        Instala o Windows SDK, ou apaga o valor de LV_SIGN_SHA1 para
echo        publicar sem assinar.
pause & exit /b 1

:sign_off
echo        Assinatura: OFF ^(LV_SIGN_SHA1 vazio^)

:sign_check_fim

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
echo [2/12]A ler a versao atual do LogViewer.csproj...
for /f "tokens=*" %%a in ('findstr /r "<Version>[0-9]" "%PROJ%"') do set LINE=%%a
for /f "tokens=2 delims=><" %%b in ("%LINE%") do set CURRENT=%%b
if "%CURRENT%"=="" ( echo [ERRO] Nao consegui ler o ^<Version^> do .csproj. & pause & exit /b 1 )
echo        Versao atual: %CURRENT%
echo        OK

echo [3/12]Nova versao N.N.N.N ^(Enter = manter %CURRENT%^):
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
echo [4/12]A atualizar LogViewer.csproj e ClickOnceProfile.pubxml...
powershell -NoProfile -Command "$p='%PROJ%'; $c=[IO.File]::ReadAllText($p); $c=$c -replace '<Version>.*?</Version>','<Version>%NEWVER%</Version>' -replace '<AssemblyVersion>.*?</AssemblyVersion>','<AssemblyVersion>%NEWVER%</AssemblyVersion>' -replace '<FileVersion>.*?</FileVersion>','<FileVersion>%NEWVER%</FileVersion>'; [IO.File]::WriteAllText($p,$c,(New-Object Text.UTF8Encoding($false)))"
if errorlevel 1 ( echo [ERRO] Falhou a atualizar o .csproj. & pause & exit /b 1 )

powershell -NoProfile -Command "$p='%PUBXML%'; $c=[IO.File]::ReadAllText($p); $c=$c -replace '<ApplicationVersion>.*?</ApplicationVersion>','<ApplicationVersion>%NEWVER%</ApplicationVersion>'; [IO.File]::WriteAllText($p,$c,(New-Object Text.UTF8Encoding($false)))"
if errorlevel 1 ( echo [ERRO] Falhou a atualizar o pubxml. & pause & exit /b 1 )
echo        OK: csproj + pubxml -^> %NEWVER%

:: ── 5. Escrever a versao no site ─────────────────────────────
:: ESTA PASTA E A FONTE DO SITE. Nao ha copia de lado nenhum: edita-se aqui e
:: e daqui que se publica, igual ao ExplorerFocus. Ate 2026-08-18 a fonte vivia
:: em ..\LogViewer\docs\ e era copiada para ca por robocopy -- duas copias, e
:: editar a errada custava o trabalho todo.
::
:: CONSEQUENCIA DIRECTA disso: NAO se pode usar um marcador tipo "__VERSION__",
:: porque o ficheiro escrito e o mesmo que se volta a ler no publish seguinte --
:: o marcador era gasto a primeira vez e nunca mais havia o que substituir, com
:: o numero do site a congelar em silencio. Reescreve-se a versao ANTERIOR, como
:: o EF faz.
::
:: E por isso que se CONTA antes de substituir: se o padrao deixar de casar (por
:: alguem ter mexido no HTML), isto tem de FALHAR e nao passar em claro.
::
:: Ler/escrever em UTF-8 SEM BOM: o PowerShell 5.1 usa ANSI por omissao e o
:: index.html tem caracteres nao-ASCII. Nao usar "Set-Content -Encoding UTF8",
:: que no 5.1 escreve COM BOM.
:: O ">" do HTML vai como \x3E no regex, para o cmd nao o ler como redireccao.
echo [5/12]A escrever a versao no site...
powershell -NoProfile -Command "$q=[char]34; $p='%DIST_INDEX%'; $v='%NEWVER%'; $c=[IO.File]::ReadAllText($p,[Text.Encoding]::UTF8); $p1='(softwareVersion'+$q+'\s*:\s*'+$q+')[\d.]+'; $p2='(class='+$q+'ver-badge'+$q+'\x3Ev)[\d.]+'; if (([regex]::Matches($c,$p1)).Count -lt 1) { exit 2 }; if (([regex]::Matches($c,$p2)).Count -lt 1) { exit 3 }; $c=[regex]::Replace($c,$p1,('${1}'+$v)); $c=[regex]::Replace($c,$p2,('${1}'+$v)); [IO.File]::WriteAllText($p,$c,(New-Object Text.UTF8Encoding($false)))"
if errorlevel 1 (
    echo [ERRO] Nao consegui escrever a versao no index.html.
    echo        Codigo 2 = nao encontrou o "softwareVersion"; 3 = nao encontrou o "ver-badge".
    echo        Alguem mexeu na marcacao do index.html: corrige o padrao neste passo.
    pause & exit /b 1
)
echo        Versao escrita no index.html: v%NEWVER%
echo        OK

:: ── 5b. Gerar as paginas por idioma ──────────────────────────
:: Tem de ser DEPOIS da injecao da versao: as 15 paginas por idioma sao
:: copias do index.html e, geradas antes, ficavam a anunciar a versao
:: anterior no cartao e no JSON-LD.
echo [5b/12]A gerar as paginas por idioma...
python "%DIST_DIR%tools\gerar-linguas.py"
if errorlevel 1 (
    echo [ERRO] O gerador das paginas por idioma falhou.
    echo        Sem ele, as 15 paginas por idioma ficam desactualizadas.
    pause & exit /b 1
)
echo        OK

:: ── 6. Parar a app + limpar artefactos ───────────────────────
:: Se o LogViewer estiver aberto a partir do bin\Release, o rmdir falha.
:: bin\Debug e preservado para nao estragar o F5 / o build manual.
echo [6/12]A parar o LogViewer ^(se aberto^) e a limpar bin\Release + obj...
taskkill /im LogViewer.exe /f >nul 2>&1
if exist "%BIN%" ( rmdir /s /q "%BIN%" & echo        Apagado: bin\Release\ )
if exist "%OBJ%" ( rmdir /s /q "%OBJ%" & echo        Apagado: obj\ )
echo        OK

:: ── 7. Compilar as 3 edicoes ─────────────────────────────────
:: Ordem: StandAlone -> ClickOnce -> Portable. As duas primeiras sao
:: framework-dependent; a Portable (self-contained) fica para o fim para
:: nao contaminar o bin\ partilhado das outras.
echo [7/12]A compilar as 3 edicoes...

echo        - restore...
dotnet restore "%PROJ%" >nul
if errorlevel 1 ( echo [ERRO] dotnet restore falhou. & pause & exit /b 1 )

echo        - StandAlone ^(single-file, framework-dependent^)...
:: Nao passar PublishProfile: a condicao "$(PublishProfile)==''" do csproj
:: e o que da o single-file. EnableCompressionInSingleFile fica DESLIGADO
:: (incompativel com SelfContained=false).
::
:: NAO REPOR o -p:IncludeAllContentForSelfExtract=true (removido 2026-09-10).
:: Com essa flag o exe desdobrava o LogViewer.dll para %TEMP%\.net\LogViewer\
:: no arranque. Esse DLL fica FORA da assinatura, e o ESET apagava-o como
:: "@Object.Suspicious" -- um exe pequeno que escreve codigo em %TEMP% e o
:: carrega e, para a heuristica, um dropper. Assinar o exe nao resolvia,
:: porque o objecto acusado era o DLL solto e nao o exe.
:: Sem a flag o DLL viaja DENTRO do exe assinado e nada e escrito em disco.
:: Era precisa no .NET 5/6 (o WPF nao encontrava os resources); testado no
:: .NET 10 em 2026-09-10: arranca bem e nao extrai nada.
dotnet publish "%PROJ%" -c Release -p:PublishSingleFile=true -p:SelfContained=false -p:RuntimeIdentifier=win-x64 -p:IncludeNativeLibrariesForSelfExtract=true -p:DebugType=none -p:DebugSymbols=false -p:PublishDir="%SA_DIR%\\" --nologo -v minimal
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
echo [8/12]A renomear o Portable, ASSINAR e criar os .zip...

if exist "%PT_PDB%" ( del "%PT_PDB%" & echo        Apagado: LogViewer.pdb )
if exist "%SA_ZIP%" ( del "%SA_ZIP%" )
if exist "%PT_ZIP%" ( del "%PT_ZIP%" )
if exist "%PT_EXE%" ( del "%PT_EXE%" )

if exist "%PT_RAW%" (
    ren "%PT_RAW%" "LogViewerPortable.exe"
    echo        Renomeado: LogViewer.exe -^> LogViewerPortable.exe
)
if not exist "%PT_EXE%" ( echo [ERRO] LogViewerPortable.exe nao existe apos o rename. & pause & exit /b 1 )

:: ── 8b. ASSINAR ──────────────────────────────────────────────
:: ⛔ A ORDEM NAO E ARBITRARIA, E E O UNICO ERRO DESTE ASSUNTO QUE PARTE TUDO
::    EM SILENCIO. Assinar ALTERA OS BYTES do ficheiro, logo tudo o que o
::    descreve tem de vir DEPOIS:
::
::      compilar -> renomear -> ASSINAR -> .zip -> version.json -> publicar
::                              ^^^^^^^
::                          aqui, e so aqui
::
::    Se o SHA-256 do [9] fosse calculado antes da assinatura, o version.json
::    publicado descrevia um ficheiro que ja nao existe: o auto-updater
::    descarregava, comparava, NAO BATIA, apagava e desistia -- e o auto-update
::    de toda a gente ficava partido ate uma release seguinte o corrigir, sem
::    erro visivel e sem ninguem dar por isso.
::
:: Assina-se DEPOIS do rename, e nao antes, para se assinar exactamente os
:: ficheiros que vao ser publicados, com o nome final. Os dois numa so chamada:
:: o signtool aceita varios ficheiros e assim pede o PIN UMA vez em vez de duas.
if not defined LV_SIGN_SHA1 goto :sign_saltar

echo        A assinar ^(pode pedir o PIN do SimplySign^)...
"%SIGNTOOL%" sign /fd sha256 /tr "%LV_SIGN_TS%" /td sha256 /sha1 "%LV_SIGN_SHA1%" /v "%SA_EXE%" "%PT_EXE%"
if errorlevel 1 (
    echo [ERRO] A ASSINATURA FALHOU. A publicacao PARA aqui, de proposito.
    echo        Nada foi enviado, por isso nada ficou inconsistente.
    echo        Causas mais provaveis: SimplySign fechado/sem sessao, ou sem
    echo        internet ^(o carimbo temporal e um servico remoto^).
    pause & exit /b 1
)

:: O verify /pa nao e decoracao: usa a politica de ASSINATURA DE CODIGO, a
:: mesma que o Windows aplica a serio. Um .exe que nao passa aqui tambem nao
:: passa na maquina de quem o descarrega -- mais vale saber agora.
"%SIGNTOOL%" verify /pa /v "%SA_EXE%"
if errorlevel 1 ( echo [ERRO] StandAlone assinado mas NAO verifica. NAO publicar. & pause & exit /b 1 )
"%SIGNTOOL%" verify /pa /v "%PT_EXE%"
if errorlevel 1 ( echo [ERRO] Portable assinado mas NAO verifica. NAO publicar. & pause & exit /b 1 )
echo        Assinados e verificados: LogViewer.exe + LogViewerPortable.exe
goto :sign_feito

:sign_saltar
echo        [aviso] LV_SIGN_SHA1 vazio: os executaveis NAO vao assinados.

:sign_feito

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
echo [9/12]A gerar o version.json ^(versao + data + SHA-256^)...
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
:: Ficheiro a ficheiro, e nao os 4 num so 'gh release create' (2026-09-17):
:: o GitHub responde HTTP 500 "Error saving asset" a meio dos ficheiros
:: grandes -- aconteceu na 1.5.3.5 e na 1.5.3.6, sempre com o Portable de
:: 159 MB -- e o gh recomeca esse ficheiro do principio em silencio, deixando
:: o ecra meia hora parado na mesma linha sem se saber o que ja subiu. Assim
:: ve-se cada ficheiro, repete-se so o que falhar (3 tentativas) e a Release
:: so deixa de ser rascunho com os 4 la dentro. Medido nesse dia: o ficheiro
:: que o gh nao conseguiu em 30 min subiu depois em 31 s (5 MB/s) -- a linha
:: e o antivirus foram descartados por medicao, a falha e do lado do GitHub.
echo [10/12]A criar a Release v%NEWVER% no GitHub ^(rascunho^)...
gh release create "v%NEWVER%" ^
    --repo "%REPO%" ^
    --draft ^
    --title "v%NEWVER%" ^
    --notes "Release v%NEWVER%. See landing page for installation options."
if errorlevel 1 (
    echo [ERRO] gh release create falhou.
    echo        Causas possiveis:
    echo          - sem ligacao a internet
    echo          - login expirado ^(corre 'gh auth status'^)
    echo        NOTA: o site ainda NAO foi enviado, nada ficou inconsistente.
    echo              Podes voltar a correr este script com a mesma versao.
    pause & exit /b 1
)
echo        OK ^(rascunho: ainda nao e visivel para ninguem^)
echo        ^(4 ficheiros, ~225 MB - o Portable sozinho leva a maior parte^)

set "ASSET_N=0"
call :SobeAsset "%SA_EXE%"
if errorlevel 1 goto :release_incompleta
call :SobeAsset "%SA_ZIP%"
if errorlevel 1 goto :release_incompleta
call :SobeAsset "%PT_EXE%"
if errorlevel 1 goto :release_incompleta
call :SobeAsset "%PT_ZIP%"
if errorlevel 1 goto :release_incompleta

echo [10/12]Os 4 ficheiros estao la: a publicar a Release...
gh release edit "v%NEWVER%" --repo "%REPO%" --draft=false --latest
if errorlevel 1 goto :release_incompleta
echo        OK
echo        URL: https://github.com/%REPO%/releases/tag/v%NEWVER%
goto :release_feita

:release_incompleta
echo.
echo [ERRO] A Release v%NEWVER% ficou incompleta e continua em RASCUNHO.
echo        O site ainda NAO foi enviado: ninguem ve nada a meio.
echo        Ve o que ja la esta e retoma SEM recompilar nem repetir o PIN:
echo          gh release view "v%NEWVER%" --repo "%REPO%" --json assets
echo          gh release upload "v%NEWVER%" "o que faltar" --repo "%REPO%" --clobber
echo          gh release edit "v%NEWVER%" --repo "%REPO%" --draft=false --latest
echo        e depois os passos 11 e 12 a mao.
pause & exit /b 1

:release_feita

:: ── 11. commit + push do repo dist ───────────────────────────
echo [11/12]git commit + push do repo dist...
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

:: ── 12. IndexNow: avisar o Bing ──────────────────────────────
:: Igual ao passo [5/5] do __publicar_site_LogViewer.cmd, onde nasceu
:: (2026-09-12). Uma release tambem muda as paginas -- a versao em todas as
:: linguas e o sitemap --, e sem isto so o publish so-site avisava o Bing.
::
:: O Bing nao e rapido a passar por si: o IndexNow avisa-o no momento do
:: publish e a indexacao passa de dias para horas. O Yandex e o Seznam usam
:: o mesmo protocolo; o DuckDuckGo vive do indice do Bing. O Google IGNORA
:: o IndexNow -- ali o que acelera e o 'Pedir indexacao' do Search Console.
::
:: A lista de enderecos NAO esta escrita aqui: sai do sitemap.xml que o
:: gerador acabou de escrever no passo [5b]. Escrita a mao, ficava para tras
:: na proxima lingua -- e ficava em SILENCIO.
::
:: A chave vive em 3ae8a566eee0cf71c4aa33092370e4ea.txt, na raiz do site. O
:: ficheiro PROVA ao Bing que quem avisa e quem manda no site, e por estar
:: dentro de /TheAbsoluteLogViewer/ limita o aviso a este site e nao a todo
:: o nunex-mbrothers.github.io. ATENCAO: se o apagares, os avisos passam a
:: ser recusados.
::
:: ESPERA PELA CHAVE antes de avisar: acabado de fazer push, o Pages pode
:: ainda nao servir o ficheiro, e o aviso vinha recusado com um 403 que nao
:: queria dizer nada de errado. Tenta 8 vezes, de 15 em 15 segundos.
::
:: NAO ABORTA: nesta altura a release e o site JA estao no ar e o IndexNow e
:: so um aviso a terceiros. Mas tambem nao passa em claro -- diz OK ou [AVISO].
echo [12/12] IndexNow: a avisar o Bing...
powershell -NoProfile -Command "$ErrorActionPreference='Stop'; try { $k='3ae8a566eee0cf71c4aa33092370e4ea'; $kl='https://nunex-mbrothers.github.io/TheAbsoluteLogViewer/3ae8a566eee0cf71c4aa33092370e4ea.txt'; $ok=$false; for ($i=1; $i -le 8; $i++) { try { if ((Invoke-WebRequest -Uri $kl -UseBasicParsing -TimeoutSec 15).Content.Trim() -eq $k) { $ok=$true; break } } catch { }; Write-Host ('       a chave ainda nao e servida; nova tentativa em 15s (' + $i + '/8)'); Start-Sleep -Seconds 15 }; if (-not $ok) { throw ('a chave nunca chegou a ser servida em ' + $kl) }; $s=[IO.File]::ReadAllText('%DIST_DIR%sitemap.xml'); $u=@([regex]::Matches($s,'<loc>([^<]+)</loc>') | ForEach-Object { $_.Groups[1].Value }); if ($u.Count -lt 1) { throw 'o sitemap nao tem nenhum endereco' }; $b=@{ host='nunex-mbrothers.github.io'; key=$k; keyLocation=$kl; urlList=$u } | ConvertTo-Json -Compress; $r=Invoke-WebRequest -Uri 'https://api.indexnow.org/indexnow' -Method Post -ContentType 'application/json; charset=utf-8' -Body $b -TimeoutSec 30 -UseBasicParsing; Write-Host ('       ' + $u.Count + ' enderecos anunciados ao Bing. HTTP ' + [int]$r.StatusCode) } catch { Write-Host ('       [AVISO] O IndexNow nao aceitou: ' + $_.Exception.Message); Write-Host '               O site ESTA publicado -- falhou so o aviso ao Bing.'; exit 1 }"
if errorlevel 1 (
    echo        Segue-se em frente: isto nao invalida o publish.
)

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
exit /b 0

:: ── subrotina do passo 10: um ficheiro, ate 3 tentativas ─────────────
:: %~1 = caminho do ficheiro. Sai com errorlevel 1 se nenhuma tentativa
:: pegar. O --clobber substitui um ficheiro que tenha ficado a meio, por
:: isso repetir e sempre seguro.
:SobeAsset
set /a ASSET_N+=1
for %%F in ("%~1") do (
    set "ASSET_NOME=%%~nxF"
    set /a ASSET_MB=%%~zF/1048576
)
:: A espera entre tentativas e um 'ping' e nao um 'timeout': o timeout aborta
:: com "Input redirection is not supported" se a entrada estiver redirecionada.
:: E dentro de um bloco ( ) os comentarios tem de ser 'rem' -- um "::" ali
:: da "The system cannot find the drive specified".
for /l %%T in (1,1,3) do (
    echo        [!ASSET_N!/4] !ASSET_NOME! ^(!ASSET_MB! MB^) - tentativa %%T de 3...
    gh release upload "v%NEWVER%" "%~1" --repo "%REPO%" --clobber
    if not errorlevel 1 (
        echo               OK
        exit /b 0
    )
    echo               falhou; nova tentativa daqui a 10s
    ping -n 11 127.0.0.1 >nul
)
exit /b 1
