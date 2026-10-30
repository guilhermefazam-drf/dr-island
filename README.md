# Dr Island

Central de controlo do dia de trabalho, no notch do MacBook: mostra o uso do **Claude**, os teus **Pull Requests** (GitHub), as tasks e a sprint do **Jira**, música, temporizador de foco e atalhos de apps. Com o rato por cima do notch (ou com o atalho ⌃⌥I), a ilha expande.

> Para a lista completa de funcionalidades e regras, ver [docs/funcionalidades.md](docs/funcionalidades.md).

## Requisitos

- macOS 14 ou superior (funciona em ecrãs sem notch, com uma pílula no topo).
- Cada integração é opcional e só precisa do que está descrito abaixo.

| Integração | O que precisas |
|---|---|
| **Claude** | Claude Code instalado e com sessão iniciada neste Mac |
| **GitHub** | GitHub CLI (`gh`) instalado e autenticado |
| **Jira** | Site Jira Cloud, o teu email e um token de API |

## Instalar

**Com o DMG:**

1. Abre o `DrIsland-<versão>.dmg` e arrasta a app para **Aplicações**.
2. Na primeira abertura, clica com o botão direito na app → **Abrir** (a app não está notarizada, por isso o macOS pede confirmação).
3. Em **Definições → Geral** liga o arranque no login, se quiseres.

**A partir do código** (precisa das Command Line Tools ou do Xcode):

```bash
scripts/bundle.sh release   # gera DrIsland.app
scripts/dmg.sh              # gera o DMG
```

## Configurar

Abre as **Definições** pelo ícone da barra de menu (⌘,).

### Claude

Não há nada a configurar. A app lê o token do Claude Code que já está no teu Keychain e mostra o uso da sessão (5 h) e da semana, com previsão de esgotamento. O custo estimado (hoje, 7 e 14 dias) vem dos registos locais do Claude Code.

- Se aparecer "sem credenciais", abre o Claude Code no terminal e faz `/login`.
- Se o Keychain pedir permissão, escolhe **Permitir sempre**.

### GitHub

A app usa o `gh`; não guarda tokens.

```bash
brew install gh
gh auth login
```

Em **Definições → GitHub** podes limitar a org/repositório (ex.: `doutorfinancas`). A app encontra o `gh` em `/opt/homebrew/bin`, `/usr/local/bin` ou `/usr/bin`; noutro sítio, indica o caminho nas Definições.

### Jira

Desligado por defeito. Em **Definições → Jira**:

1. Cria um token em <https://id.atlassian.com/manage-profile/security/api-tokens>.
2. Preenche **Site** (`empresa.atlassian.net`), **Email** (o da tua conta Atlassian) e cola o **token**. Fica guardado só no Keychain.
3. Carrega em **Testar** e liga o Jira.

As tasks vêm do JQL configurado (por omissão, as que estão atribuídas a ti e por concluir). A secção "Aprovações" usa o campo personalizado `customfield_10127` da instância da Doutor Finanças; noutra instância, ajusta o JQL nas Definições.

#### Sprint

Com o Jira ligado e uma sprint ativa, o título do card Jira passa a "Jira - SPRINT - nome", com uma barra do tempo decorrido (passa o rato para ver as datas, a % e o tempo que falta; o fim é o planeado). A app descobre sozinha o campo Sprint da tua instância.

- O card Jira da sprint ativa tem um fundo azul com contorno fino, para se distinguir dos outros.
- Em **Definições → Jira → Sprint** (ou **Conteúdo**) podes ligar e desligar a sprint. As tasks e os PRs aparecem sempre todos nas listas normais; o que está por planear está no card **Backlog**.

### Permissões do macOS

Nenhuma é obrigatória; sem elas, só a funcionalidade indicada fica de fora.

| Permissão | Para quê |
|---|---|
| **Automação** (Spotify, Música) | Ler e controlar o que está a tocar |
| **Acessibilidade** | Botões de play/pausa e faixa seguinte do leitor |
| **Acesso Total ao Disco** | Detetar o Focus do macOS e silenciar os avisos |
| **Notificações** | Avisos do macOS (só com a app instalada como `.app`) |

## A ilha

Uma borda à volta do notch enche à medida que gastas a sessão do Claude (fica vermelha sem internet). Com o rato por cima, ou com o atalho global (⌃⌥I por omissão, configurável em **Definições → Geral**), a ilha abre no ecrã onde está o rato.

Cada bloco está num card próprio e pode ser movido entre 1 a 3 colunas em **Definições → Layout**:

- **Claude** — uso da sessão e da semana, e histórico.
- **Git** — Os meus PRs, A rever; menu de contexto para abrir, copiar o link ou silenciar um PR.
- **Jira** — As minhas tasks, Aprovações.
- **Música** — Spotify, Música e o que toca no browser.
- **Foco** — temporizador Pomodoro (também na barra de menu).
- **Avisos recentes**, **Resumo do dia** e **Linha do tempo** dos eventos de hoje.

Por baixo das colunas fica o dock de **atalhos de apps** (Definições → Atalhos), com pasta opcional para abrir um projeto diretamente no editor.

### Avisos

Quando algo muda (review pedido, CI, aprovação, comentário, conflito, nova task no Jira…), a ilha avisa pelos canais que escolheres em **Definições → Avisos**: pulso na borda, ponto azul, linha destacada, mini ilha, confetti, notificação do macOS e som. O **Não incomodar** (manual, horário silencioso ou Focus do macOS) silencia o som e as notificações. O histórico dos últimos 30 dias está no menu da barra → **Histórico de avisos…** e em **Definições → Dia**.

De manhã, se houver novidades, a mini ilha anuncia o **resumo do dia** com o que mudou desde a última vez que viste a ilha.

### Aparência e movimento

Em **Definições → Aparência** escolhes o efeito de abrir e fechar (Mola, Génio, Gota, Dissolver, Dobradiça, Fenda), a velocidade e a elasticidade, com pré-visualização.

Com **Reduzir movimento** ligado no macOS (Definições do Sistema → Acessibilidade → Ecrã), a ilha usa um fade curto em vez dos efeitos, e o cometa, os brilhos, o confetti, a magnificação do dock e o texto a deslizar ficam desligados.

## Problemas comuns

- **Os PRs não aparecem:** corre `gh auth status` no terminal.
- **Sem avisos do macOS:** a app tem de estar instalada como `.app` e com notificações permitidas.
- **Não incomodar com o Focus do macOS:** precisa de Acesso Total ao Disco.
- **O botão de pausa deixou de funcionar depois de uma build:** a assinatura ad-hoc mudou; volta a dar a permissão de Acessibilidade.
- **A sprint não aparece:** confirma que o Jira está ligado, que há uma sprint ativa e que **Definições → Jira → Sprint** está ligado; se falhar, o motivo fica no registo de erros.
- **Registo de erros:** menu da barra → **Registo de erros…**.

## Desenvolvimento

Swift Package sem projeto Xcode, com dois módulos:

- `DrIslandCore` — lógica pura e testada (clientes de API, deteção de alterações, custo, sprint, layout).
- `DrIsland` — a app em AppKit/SwiftUI (stores `@Observable`, painéis da ilha, Definições).

```bash
scripts/bundle.sh debug     # build de desenvolvimento (para se a compilação falhar)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter SprintTests
```

- `swift build` simples falha por falta do plugin de macros do SwiftUI no SDK 27; o `scripts/bundle.sh` fixa o SDK 26 (muda com `SDKROOT_OVERRIDE`).
- A verificação estrita de concorrência está ligada: a build deve sair sem avisos.
- Para depurar: `DR_ISLAND_SNAPSHOT=<png>` grava um render da ilha, `DR_ISLAND_FAKE=0..1` força a % do Claude sem rede e `DR_ISLAND_COLLAPSED` mantém-na fechada.
- Cada tipo vive no seu ficheiro. Ao mudar comportamento, atualiza o [docs/funcionalidades.md](docs/funcionalidades.md).
