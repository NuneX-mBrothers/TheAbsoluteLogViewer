# Auto-update — versão standalone single-file

## O que ficou implementado

### Novo
- **`Services/UpdateService.cs`** — verificação remota, download, instalação via batch helper.

### Modificados
- **`LocalizationService.cs`** — 11 chaves novas em 12 idiomas.
- **`MainViewModel.cs`** — `CheckForUpdatesCommand`, método `CheckForUpdatesAsync(silent)`, kick-off silencioso no arranque.
- **`1-prepare.cmd`** — apenas mensagens (limpeza já cobre standalone).
- **`2-publish.cmd`** — copia o `.exe` standalone para `LogViewer-dist\standalone\` e regenera `version.json` automaticamente.
- **`index.html`** — dois cards no install (ClickOnce + Standalone), CTA hero com ambos os botões, textos atualizados.

## O que o João tem de fazer

### 1. Adicionar o botão no `MainWindow.xaml` (secção About)
Snippet em `UpdateButton-snippet.xaml` — cola na zona About.

### 2. Primeira execução do pipeline (criar pasta standalone)
- Correr `1-prepare.cmd` (escolher versão)
- VS → **Publish** com perfil ClickOnce (continua a publicar como antes)
- VS → **Publish** standalone (gera `bin\Release\net10.0-windows\win-x64\LogViewer.exe`)
- Correr `2-publish.cmd` — automaticamente:
  - Copia `LogViewer.exe` para `LogViewer-dist\standalone\LogViewer.exe`
  - Gera `LogViewer-dist\standalone\version.json` com a versão actual
  - Faz commit & push para o GitHub Pages

### 3. Em cada release subsequente
Mesmo workflow — `1-prepare` → Publish (ambos) → `2-publish`.

> **Nota:** se só fizeres Publish ClickOnce e correres o `2-publish.cmd`, ele avisa que o standalone .exe não existe e pergunta se queres continuar mesmo assim (modo "só ClickOnce"). Util para hotfixes ClickOnce.

## Como funciona em runtime

**Arranque (silencioso):**
- ClickOnce → o código não corre (`UpdateService.IsSupportedDeployment` retorna `false`).
- Standalone:
  1. Background task descarrega `version.json`
  2. Compara com `Assembly.GetEntryAssembly().GetName().Version`
  3. Se houver versão nova → diálogo "v1.2.x → v1.3.x. Atualizar agora?"
  4. Falhas de rede são silenciadas.

**Manual (botão na About):**
- Igual ao arranque, mas:
  - Se up-to-date → mostra "Está a usar a versão mais recente (X.Y.Z.W)."
  - Se erro → mostra detalhes
  - Se ClickOnce → mostra info explicando que esse modo tem auto-update próprio

**Quando o utilizador aceita:**
1. Download para `%TEMP%\TheAbsoluteLogViewer-update\LogViewer_<v>.exe`
2. Geração de `apply-update.cmd` que:
   - Aguarda o PID actual encerrar (até 30s)
   - Substitui o `.exe` (com retry de 10s para handles a soltar)
   - Relança a app
   - Auto-apaga
3. Mensagem de aviso e `Application.Current.Shutdown()`

## Notas técnicas

- HTTP com `Cache-Control: no-cache` (evita servir versões antigas em cache do CDN).
- O batch helper só substitui o exe **depois** do PID actual encerrar — sem isto o Windows não permite a substituição.
- Nome do `.exe` é descoberto dinamicamente via `Environment.ProcessPath` — se renomeares mais tarde, continua a funcionar.
- Em caso de falha do `copy`, o helper abre o Explorer no `%TEMP%` para o utilizador ver/aplicar manualmente.
- **Não** há rollback automático nem verificação de assinatura digital.

## Sugestões / melhorias futuras

1. **Verificação de Authenticode** do `.exe` descarregado contra o thumbprint conhecido (`FB18F6D2BDBFDB7FD71B23A32685980E339DFCBA`) antes de aplicar.
2. **Toggle "Verificar updates ao arranque"** no Settings.
3. **Throttling**: só verificar a cada N horas (guardar último check em `UserStateService.SetExtra`).
4. **Barra de progresso real** durante o download.
5. **Release notes** no diálogo (o `version.json` aceita facilmente o campo `notes_pt`/etc.).
