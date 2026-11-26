# Dr Island — regras de negócio e features (v0.2.0)

Levantamento factual, a partir do código, de todas as features e regras da app Dr Island (antes "Token Island"): central de controlo do dia de trabalho da equipa de dev da Doutor Finanças, apresentada como "Dynamic Island" no notch do MacBook.

## Visão geral

- App nativa macOS que reúne: Claude (uso e custo), PRs GitHub, tasks Jira, música, temporizador de foco e atalhos de apps.
- Uma borda à volta do notch enche conforme se gasta a sessão de 5h do Claude; com o rato por cima, a ilha expande.
- Ecrãs sem notch usam uma pílula (150pt).
- Migração: na 1ª execução migra as definições do bundle antigo `com.fazam.token-island`. O arranque no login tem de ser religado.
- Registo de erros em ficheiro (`ErrorLog`): erros das fontes, exceções, crashes, UI bloqueada. Acessível pelo menu da barra ou Definições → Registo.

## Arquitetura e stack

| Item | Detalhe |
|---|---|
| Linguagem/UI | Swift, SwiftUI, AppKit |
| Build | Swift Package, macOS 14+, sem Xcode |
| Módulos | `DrIsland` (UI/stores) e `DrIslandCore` (lógica pura testada) |
| Helper | `helper/nowplaying.c` e `.pl` (Now Playing do sistema) |
| SDK | 26 fixo: o SDK 27 das CLT não traz o plugin de macros do SwiftUI |
| Cor da marca | `#00A6E5` (`make-icon.swift`) |
| Debug | `DR_ISLAND_SNAPSHOT=<png>` grava o render; `DR_ISLAND_FAKE=0..1` força a %; `DR_ISLAND_THEME`, `DR_ISLAND_DENSITY`, `DR_ISLAND_STYLE`, `DR_ISLAND_COLUMNS` (1–3) e `DR_ISLAND_SNAPSHOT_DELAY` (segundos, default 3) forçam tema, tamanho, colunas e o atraso do render |
| Processo | Mantido acordado (`beginActivity`), pois o painel transparente click-through pode ser limitado pelo macOS |

## Features por bloco

1. **Claude (uso)** — medidor de sessão (5h) e semana, previsão de esgotamento, estimativa local, histórico.
2. **Custo e tokens** — hoje / 7 d / 14 d / total, por família de modelo.
3. **Pull requests (GitHub)** — meus, a rever, alterações detetadas, silenciar.
4. **Jira** (só leitura: a app nunca cria, edita, transita nem comenta nada no Jira; só faz consultas `GET`, e o cliente recusa qualquer outro método) — card "Sprint atual", card "Backlog" (backlog da equipa por sprint) e, abaixo deles, o card "Jira" com "As minhas tasks" e "Aprovações".
   - Com uma sprint ativa (e «Sprint» ligado) existe o card «Sprint atual» (`IslandBlock.sprint`), com fundo azul da marca e contorno fino (`blockCard(active:)`). Mostra a sprint ativa de cada **stream** (board scrum do Jira): `jiraSprintBoards` guarda os ids escolhidos nas Definições, que lista os boards pelo nome (`GET /rest/agile/1.0/board?type=scrum`, só leitura). Sem nenhum escolhido, usa as streams das sprints onde já tive tasks (`assignee was currentUser()`); um diretor escolhe todas as que quer ver. Com uma sprint, o título é «SPRINT - nome» com a barra de tempo; com várias, «Sprints atuais» e uma secção por sprint («nome · tempo restante», e «nome · Aprovações»). Uma sprint continua «ativa» até ser fechada no Jira, mesmo depois do fim planeado, e é essa que se mostra (por board, a que começou mais tarde). Lista as tasks dessas sprints (por id, `cf[N] in (…)`) que são ou **já foram minhas** (`assignee was currentUser()`), para seguir o estado até ao fim mesmo depois de passarem a outro responsável (teste, revisão); as concluídas (statusCategory Done) não aparecem; as minhas vêm primeiro, o dono atual aparece na tag. As aprovações de tasks de uma sprint mostrada ficam nesse card. Não gera alertas. O card «Jira» (minhas tasks + aprovações) já não tem o estilo da sprint. Não há secção «Fora da Sprint»: as tasks e os PRs ficam todos nas listas normais (o que não está na sprint ativa vê-se no card Backlog).
5. **Música** — Spotify, Música e Now Playing do sistema.
6. **Foco (Pomodoro)**.
7. **Atalhos de desenvolvimento** — dock de apps.
8. **Avisos** — canais, não incomodar, histórico.
9. **Resumo do dia e linha do tempo**.
10. **Layout e aparência**, barra de menu, atalho global.

Blocos disponíveis no layout: Claude, Pull requests, Sprint atual, Backlog, Jira, Foco, Histórico, Música, Avisos recentes, Resumo do dia, Linha do tempo.

## Regras de negócio por domínio

### 1. Claude (uso)

**Fonte**
- Token OAuth do Claude Code lido do Keychain (`Claude Code-credentials`, via `/usr/bin/security`; aceita hex).
- `GET https://api.anthropic.com/api/oauth/usage` com header `anthropic-beta: oauth-2025-04-20`, timeout 15s.
- Janelas `five_hour` (sessão) e `seven_day` (semana): `utilization` 0–100 + `resets_at` (o parser tolera 6 casas decimais).
- O token nunca é guardado nem registado.

> [!warning] Endpoint não documentado
> Pode mudar sem aviso.

**Erros**: `noCredentials`, `unauthorized` (401/403), `rateLimited` (429), `http`, `network`, `invalidResponse`.
- No 429 lê `Retry-After` (segundos ou data HTTP) ou headers `anthropic-ratelimit*reset`; só valores >0 e <24h; usa o máximo.

**Cores**: níveis normal / aviso (âmbar) / crítico (vermelho).

| Limiar | Default | Regra |
|---|---|---|
| Âmbar | ≥60% | slider 10–100, passo 5 |
| Vermelho | ≥85% | nunca abaixo do âmbar |

**Limite semanal diário**: a barra "Semana" está dividida nos 5 dias úteis da janela semanal (20% cada; fins de semana não somam). A marca branca é o que se pode ter gasto *agora*: dias úteis já terminados × 20% + a parte de hoje proporcional ao tempo de trabalho (8 h a partir da hora de início, configurável em Claude → Horário de trabalho, por omissão 09:00; 1 h de almoço a meio, 4 h depois do início, em que a marca pára; antes do início conta 0 e depois do fim conta o dia inteiro), com mínimo de 1 hora de trabalho para não dividir por zero; o que sobra de dias anteriores acumula. A cor usa os mesmos limiares âmbar/vermelho da sessão, aplicados a `uso semanal ÷ permitido até hoje` (`WeeklyPace`). Sem `resets_at`, usa a % semanal simples.

**Refresh**

| Parâmetro | Valor |
|---|---|
| Intervalo | default 120s (60–600s) |
| Mínimo entre pedidos | 1 a cada 20s |
| "Atualizar agora" | debounce 3s; ignora cache/bloqueio, mas NÃO corta um bloqueio ditado pelo servidor |
| Após arranque | leitura em cache recente evita pedido |
| Após falhas | backoff exponencial base×2^(falhas-1), máx 600s |
| Após 429 | espera do servidor (+2s); sem cabeçalho, 5 min a duplicar até 15 min; entretanto mantém estimativa fresca a cada ≤60s |

**Estados**: loading, ok, noCredentials, unauthorized, offline, rateLimited.
- Se uma atualização falha, mantém a última leitura (esbatida).
- Cache local em UserDefaults (só números); janela já reiniciada → 0.

**Estimativa local** (fallback, ligada por defeito)
- Usada quando a API está limitada ou offline. Estima a % a partir dos transcripts do Claude Code (`~/.claude/projects/**/*.jsonl`, só leitura, últimos 14 dias, cache por ficheiro path+mtime+size).
- Tokens contados = input + output + cache_creation (cache reads fora).
- Deduplicação por `message.id|requestId`.
- Blocos de 5h começam à hora certa da 1ª mensagem; novo bloco se passa o fim ou há >5h sem atividade.
- Limite (100%) por prioridade:
  1. manual (definição, tokens/sessão; 0 = automático);
  2. calibrado (a partir de leitura real da API ≥3%; recalibra no máx. a cada 10 min);
  3. maior bloco passado;
  4. desconhecido (sem fração).
- Uma estimativa só pelo histórico não substitui leitura real com <30 min.
- A UI mostra "≈" quando é estimativa. Botão **Calibrar** nas definições (escreve a % real do `/usage`).

**Previsão de esgotamento** ("esgota às HH:mm")
- Usa leituras da última hora (máx. 60 amostras); precisa de ≥10 min de histórico e crescimento ≥1 ponto percentual.
- Só mostra se o ETA for antes do reset; amostras reiniciam quando a % desce.
- Toggle `showForecast` (default ligado).

**Nova sessão**
- Leitura real cujo fim da janela é >10 min posterior ao anterior (ou antes sem janela). A 1ª leitura e as estimativas não contam.
- Dispara animação da borda (flash; com a mini ilha visível, o cometa corre no contorno dela, ver [[#7. Avisos (alertas)]]) e "mini ilha" "Nova sessão do Claude iniciada" (nunca vai para o histórico nem conta como não visto).

**Histórico do uso**: pico diário (sessão e semana) dos últimos 60 dias guardado; gráfico dos últimos 14 dias, com a semana anterior mais clara (bloco "Histórico", default desligado).

**Medidor**: barra ou anel (Definições → Conteúdo). Mostra % usada, "Sessão · 5 h", tempo até ao reset (formatos "agora", "Xm", "Xh YYm", "Xd Yh") e "Semana %" (`showWeekly`, default ligado).

**Borda**: espessura 1–8pt (default 3), ligar/desligar. Animação a cada leitura fresca e na nova sessão. Só visível com borda ligada, ilha fechada e sem app em ecrã inteiro.
- Definição `claudeUpdateAnimation` ("Ao atualizar o uso", Definições → Claude; default ligado): só toca com a borda ligada, a ilha fechada, sem app em ecrã inteiro e sem a mini ilha visível (o anel fica escondido). Opções vizinhas na mesma secção: "Ao começar uma sessão nova" (cometa, `claudeNewSessionAnimation`) e o aviso de nova sessão.

### 1b. Custo e tokens

- `CostStore` refresca a cada 5 min. Master switch `costEnabled` (default ligado); sem ele não varre os logs.
- Mostra hoje, 7 dias, 14 dias, total e por família (Opus / Sonnet / Haiku / Outros, pelo nome do modelo).
- Preços editáveis, em USD por milhão de tokens:

| Família | Input | Output |
|---|---|---|
| Opus | 5 | 25 |
| Sonnet | 3 | 15 |
| Haiku | 1 | 5 |
| Outros | 3 | 15 |

- Cache write = 1,25× o preço de input; cache read = 0,1×.
- Os tokens mostrados não incluem cache reads (mostrados à parte).
- Formatação: "1,2 M", "340 mil", "$1,23" / "$12".
- Mostrar na ilha: `showCost` (default desligado).

> [!warning] Estimativa
> É "equivalente à API", não o gasto real de quem tem subscrição. Preços a confirmar em anthropic.com/pricing.

### 2. Pull Requests (GitHub)

**Fonte**
- CLI `gh` já autenticado (a app não usa tokens). Procura em `/opt/homebrew/bin`, `/usr/local/bin`, `/usr/bin` ou caminho manual; `gh api graphql` com PATH fixo.
- Erros: `notInstalled`, `notAuthenticated`, `failed(msg)`, `invalidResponse`.

**Listas**
- "Os meus PRs": `author:@me`.
- "A rever": `review-requested:@me` + `reviewed-by:@me -author:@me` (mantém PRs já aprovados/rejeitados pelo utilizador).
- Menções: `mentions:@me`, só para alertas, nunca listadas.
- Merged do utilizador: últimos 10, só para distinguir merged de fechado.
- Filtros: `is:pr is:open archived:false sort:updated-desc`. Âmbito opcional por org ou org/repo, separados por vírgula (caracteres válidos: letras, números, `.`, `_`, `-`).
- Limite 1–50 (default 20; 10 nas menções/merged).
- Só PRs com `state` OPEN (o índice de pesquisa atrasa-se).

**Campos**
- CI: SUCCESS → passing; FAILURE/ERROR → failing; PENDING/EXPECTED → pending; resto none.
- Review, rascunho, nº de comentários.
- Conflitos: `mergeable` CONFLICTING; se UNKNOWN mantém o último estado conhecido para não oscilar.
- Autor: a consulta GraphQL pede `author { login ... on User { name } }` em cada PR e `viewer{login}` sempre. `PullRequest.author` = nome (ou login se não houver nome); `PullRequest.isMine` = é PR meu (role authored ou login do autor == viewer).

> [!important] Regra de aprovação da equipa
> Um PR só conta como "aprovado" com **≥2 aprovações de humanos** (`requiredHumanApprovals=2`) **e** uma aprovação do **CodeRabbit** (login a começar por "coderabbit"). O `reviewDecision` do GitHub (1 aprovação chega) não é fiável para isto.
> - A regra é calculada pelo **app** (função `overallReview`) a partir da review mais recente de cada pessoa (`latestOpinionatedReviews`), contando pessoas distintas.
> - O CodeRabbit conta à parte e não entra nas 2 aprovações humanas.
> - `CHANGES_REQUESTED` do GitHub continua a ganhar (é a única dependência do `reviewDecision`).
> - Sem cumprir a barra → `reviewRequired`; cumprida, mesmo com `reviewDecision` vazio → aprovado.

**PRs "a rever"**
- O estado mostrado é o veredito do próprio utilizador (approved/changesRequested); `teamReview` guarda o estado global.
- Nas linhas de revisão, a etiqueta e o ícone refletem a barra da equipa, não só o veredito do utilizador: se o utilizador aprovou mas `teamReview` != approved, a linha mostra a etiqueta azul "aprovaste" e um visto cinzento (dica "Aprovaste; faltam aprovações"); "aprovado" verde e selo verde só quando `teamReview == approved`.
- PRs já revistos pelo utilizador sem pedido pendente continuam listados (`reviewPending=false`) e nunca geram "novo review".

**Atenção (ponto/cor)**: só PRs próprios. Crítico se o CI falha; aviso se há alterações pedidas ou conflitos. PRs silenciados não acendem o ponto.

**Resposta truncada**: se a lista própria/a rever estava não-vazia e vem vazia (200 com lista vazia), repete até 3× com 2s de intervalo antes de acreditar.

**Refresh**: default 120s (60–600). Em erro mantém o último snapshot; problemas de setup repetem em ≤30s; outros com backoff até 900s. Desligar GitHub limpa a lista.

**UI**
- Linha por PR: ícone de CI, aviso de conflitos, ícone de review, `#n`, título, tag (alteração não vista ou motivo de atenção), "draft", e no fim a marca de dono (ver [[#10. Marca de dono nas linhas]]).
- Clique abre no navegador. Controlos "+N mais / mostrar menos" e "+N não listados".
- Botão direito: Abrir no navegador, Copiar link, Abrir o CI com falha (`/checks`), silenciar PR (1 hora / 1 dia / até eu reativar), silenciar repositório (1 dia / até reativar), Reativar avisos.

**Alterações detetadas**
- Baseline de "fingerprints" guardada em UserDefaults (apanha mudanças com a app fechada). A 1ª leitura é só baseline e não avisa; só leituras bem-sucedidas comparam.

| Evento | Regra |
|---|---|
| novo review | PR novo em "a rever" com pedido pendente |
| menção | PR onde fui mencionado |
| novo comentário | sobem os comentários dos OUTROS (total − meus); os meus não avisam; não em PRs a rever. Ver nota abaixo |
| CI falhou / CI passou / aprovado / alterações pedidas / conflitos | só PRs próprios |
| merged | PR sai da lista, é meu e está nos merged recentes; a mensagem inclui o título do PR (guardado na fingerprint): "GIT - PR merged: #123 Título" |
| left (de outra pessoa) | a mensagem junta as iniciais de quem abriu o PR (guardadas na fingerprint): "GIT - PR #123 de LC foi aceito"; sem iniciais (PRs meus fechados sem merge, ou guardados por versões antigas): "GIT - PR #123 saiu da lista" |
| fechado/left | PR sai da lista; só reportado se `alertOnClose`; PRs revistos ainda abertos não contam como fechados; menções não reportam saída |

> [!info] Contagem de comentários (só de outros)
> - `totalCommentsCount` = comentários da conversa + comentários inline (review threads) + corpos de reviews não vazios (confirmado no PR 2493: 1+4+1=6).
> - A consulta pede os autores: `comments(last: 30)`, `reviews(last: 30){author body}`, `reviewThreads(last: 30){comments(first: 10)}`.
> - O app conta os do utilizador em `PullRequest.ownCommentCount` (função `ownComments`) e guarda-o na impressão digital (`PRFingerprint.ownCommentCount`). Só há "novo comentário" quando sobem os comentários dos outros (total − meus).
> - Caches antigos sem a contagem própria tratam-na como 0, sem alertas falsos.

**Silenciar**
- `PRMute` por PR (`pr:<url>`) ou repositório (`repo:owner/name`), com prazo ou permanente. Expirados são removidos. Geridos em Definições → Avisos.

**Tons/cores**

| Tom | Eventos |
|---|---|
| crítico | CI falhou, offline |
| aviso | alterações pedidas, conflitos |
| info | review pedido, comentário, menção, Jira, resumo |
| sucesso | aprovado, CI passou, merged, online, nova sessão |
| neutro | fechado |

### 3. Jira

**Ligação**
- API REST v3 `rest/api/3/search/jql`, Basic auth email:token. Site "empresa.atlassian.net" ou URL (só https; HTTP rejeitado).
- Token API no Keychain (serviço `com.fazam.token-island`, conta `jira-api-token`); nunca em UserDefaults, ficheiros ou logs. Token em memória (cache) para não bater no Keychain; lido fora da main thread.
- Botão "Testar" (`/myself`). Desligado por defeito.

**Tasks**
- JQL (editável): `assignee = currentUser() AND statusCategory != Done ORDER BY priority DESC, updated DESC`.
- Máx. tasks 1–20 (default 20; a API suporta até 50).
- Refresh default 180s (60–900); backoff até 900s; mantém a última lista em erro.
- Estados: disabled, notConfigured, loading, ok, unauthorized, invalidSite, offline, rateLimited, error(code).

**Ordenação**: Sprint Goal primeiro (label `Sprint_Goal`, qualquer capitalização, tolera `-`/`_`/espaço), depois "em curso" (statusCategory indeterminate), depois o resto, mantendo a ordem do JQL dentro de cada grupo. Tag "★ sprint goal" a amarelo.

**Tipo de issue**: cada task mostra um ícone do tipo antes da chave (`issuetype`): bug = joaninha vermelha (só o ícone; o fundo vermelho da linha é para tasks com a flag do Jira, campo `customfield_10006`, abaixo do destaque de alerta e do sprint goal), feature/story/melhoria = faíscas verdes, task = quadrado azul, epic = raio roxo, subtask = seta cinzenta; tipos desconhecidos não levam ícone. Tolera maiúsculas, acentos e nomes em português (`JiraIssueKind`).

**Bloco "Aprovações"** (`jiraApproverEnabled`, default ligado)
- Tasks onde sou approver, via campo custom "Approvers" `customfield_10127`. JQL default: `cf[10127] = currentUser() AND statusCategory != Done ORDER BY updated DESC`.
- O antigo `approver = currentUser()…` é migrado automaticamente (`approver` não é campo JQL neste Jira).
- Independente da leitura principal: se falhar, mantém a última lista e marca erro sem esconder as tasks próprias.
- Tasks já anunciadas na lista própria não são anunciadas duas vezes.

**Card "Backlog"** (`jiraBacklogEnabled`, default ligado; bloco próprio no layout, `IslandBlock.backlog`)
- Backlog da equipa, como a vista Backlog do Jira: uma lista por cada sprint futura (ordenadas pela data de início; sem data vão para o fim, por id) e, no fim, "Backlog" com as tasks sem sprint futura. Grupos vazios não aparecem. A sprint ativa não entra (tem o seu próprio bloco).
- JQL default: `project = <PROJ> AND statusCategory != Done AND (sprint is EMPTY OR sprint in futureSprints()) ORDER BY rank`. Projeto em `jiraBacklogProject`; vazio = o prefixo de chave mais comum nas minhas tasks. `jiraBacklogJQL` preenchido substitui o default. Sem projeto: "Indica o projeto do backlog nas Definições".
- O grupo vem do campo Sprint (auto-descoberto): sprint com `state == future` (a mais cedo se houver várias). Ordem do JQL (rank) mantida dentro de cada grupo.
- Lê até 100 tasks (2 páginas de 50, `nextPageToken`); havendo mais, nota "Só as primeiras 100 tasks do backlog".
- Cada grupo mostra 4 tasks com "+N mais" / "mostrar menos" (até 8 expandidas). Título do grupo: "<sprint> · N".
- Lido no mesmo ciclo que o resto do Jira mas à parte: se falhar mantém os últimos grupos ("Jira: JQL do backlog inválido" se nunca leu). Não gera alertas.

**Linha**
- Ícone do tipo, chave, resumo, ícone de prioridade, tag de estado, tag de alerta e, no fim, a marca de dono (ver [[#10. Marca de dono nas linhas]]). Clique abre `/browse/<KEY>`.
- Os campos pedidos à API passam a incluir `assignee`; `JiraTask.assignee` = displayName do responsável. O app lê o nome da própria conta uma vez (`/myself`, guardado em `JiraStore.myName`) e a task é "minha" quando coincide.
- Prioridade: Highest/Blocker/Critical vermelho (⌃⌃); High/Major laranja (⌃); Low/Minor e Lowest/Trivial azul-petróleo (⌄).

**Alertas Jira** (mesmos canais que os PRs; `alertJira` default ligado): task nova, mudança de estado ("passou a «X»"), novo comentário (só se for de outra pessoa), aprovadores alterados/removidos. A 1ª leitura é só baseline.
- Comentários próprios não avisam: `JiraTask.commentAuthors` (displayName dos autores em `fields.comment.comments`) é comparado com o nome da conta (`JiraStore.myName`, lido antes da comparação); guarda-se `JiraFingerprint.ownCommentCount` e a comparação é `JiraDiff.changes(from:to:me:)`.

### 4. Música

- Bloco "Música" (`showMusic`, default ligado). Poll a cada 4s.
- Fontes: Spotify e Música (AppleScript; só consulta apps já a correr para não as lançar; pede permissão de Automação) e qualquer outra fonte via Now Playing do sistema (Brave, Safari, podcasts), lido por helper dentro de `/usr/bin/perl`.
- Desde macOS 15.4 só processos Apple-signed respondem; numa execução `swift run` sem helper essa fonte não existe.
- Prefere o que está realmente a tocar. Mostra título, artista, capa (só https, ou bytes do sistema) e barra de progresso que avança entre polls.
- Controlos: play/pausa, anterior/seguinte via teclas de media (`MediaKeys`; pode precisar de Acessibilidade). Clique abre a app de origem.
- Vazio: uma só linha, "Nada a tocar".

### 5. Temporizador de foco (Pomodoro)

Bloco "Foco" (`showFocus`, default desligado).

| Parâmetro | Default | Limite na UI |
|---|---|---|
| Foco | 25 min | 5–120 (passo 5) |
| Pausa curta | 5 min | 1–30 |
| Pausa longa | 15 min | 5–60 |
| Pausa longa a cada | 4 rondas | 2–8 |
| Auto-iniciar | desligado | — |

- Estado puro (`FocusTimer`): fases foco / pausa / pausa longa. Pausar guarda o tempo restante.
- Saltar uma fase de foco NÃO conta ronda; reset volta à 1ª ronda, parado.
- A contagem só avança no fim real de foco; após N rondas completas → pausa longa.
- Estado persistido: sobrevive a reinício e recupera fases que acabaram com a app fechada.
- O fim de fase avisa pelos canais de aviso (pulso, mini ilha, som, notificação), respeitando Não incomodar.
- Barra de menu: ● foco / ☕︎ pausa, mm:ss, atualiza a cada segundo.

### 6. Atalhos de desenvolvimento

- Dock centrado sob as colunas (não é um bloco movível). Apps à escolha (arrastar para ordenar), com pasta opcional (abre a app nessa pasta, p. ex. projeto no VS Code, se a pasta existir). Clique abre ou traz para a frente.
- A mesma app não se adiciona 2×.
- Sugestões, se instaladas: VS Code, Cursor, Claude, Xcode, IntelliJ (+CE), PhpStorm, WebStorm, PyCharm, Android Studio, Warp, iTerm, Terminal, Docker, Postman, TablePlus, Sublime Text, GitHub Desktop.
- Ícones em alta resolução numa pílula justa; o ícone por baixo do rato cresce um pouco (12%, nada com «Reduzir movimento»).

### 7. Avisos (alertas)

**Canais** (cada um opcional; combinam-se)

| Canal | Default | Notas |
|---|---|---|
| Pulso da borda | ligado | 2 flashes, cor do tom |
| Ponto azul | ligado | até abrir a ilha |
| Linha destacada com tag | ligado | |
| Confetti | ligado | só aparece com a Mini ilha ligada; definição `alertConfetti` (default ligado) em Definições → Avisos; botão "Testar confetti" simula um PR aprovado; ~2,2 s, 36 peças, animação guiada pelo relógio (`ConfettiBurst`, TimelineView) que dispara em PR aprovado ou merged |
| Banner | desligado | a ilha abre sozinha uns segundos |
| Notificação macOS | desligado | requer bundle `.app` |
| Som | desligado | Basso = crítico, Glass = sucesso, Tink = resto |

- "Mini ilha" (peek): mostra só o que mudou durante ~3,5s + 0,5s por linha extra (máx. de linhas definido). O hover abre a ilha completa e substitui-a.
- **Fusão de alertas**: alertas seguidos fundem-se em vez de se substituírem. As leituras do GitHub e do Jira chegam com segundos de diferença e a segunda substituía a primeira (causa de "o alerta corre mas não exibe nada" e de comentários que não apareciam). `IslandInstance.peek` junta as novas linhas às existentes (máx. 4, ficam as mais recentes, sem duplicados por id) e reinicia o temporizador.
- **Avisos com a ilha aberta**: um aviso que chega com a ilha completa aberta (hover, atalho) ou durante a pré-visualização do efeito já não se perde: fica guardado (`IslandInstance.heldPeek`, máx. 4, sem duplicados) e a mini ilha mostra-o assim que a ilha fecha (0,6 s depois, no fim da animação de fecho). Vale em Camadas e Bento.
- **Nova sessão na mini ilha**: com a mini ilha visível (Mini ilha e aviso de nova sessão ligados), o cometa e o brilho verde percorrem o CONTORNO da mini ilha (`miniSessionAnimation`, usa `IslandShape` com `outlineOnly`), os dois brilhos (sparkles) aparecem ao lado dela e a mini ilha abre logo (atraso de 0,15 s em vez de 1,4 s à espera da volta do cometa). Sem mini ilha, continua no anel do notch.

**Origem do aviso**
- Todas as mensagens começam pela origem, no formato `ORIGEM - texto`: `GIT - PR aprovado: #n`, `JIRA - Novo comentário em TEP-1`. Outras origens: `CLAUDE` (nova sessão), `REDE` (offline/online), `RESUMO` (briefing, só o título).
- Vale para a notificação do macOS, a mini ilha (marca pequena com a origem antes do código), o bloco "Avisos recentes", o histórico (Definições → Avisos e Dia) e a linha do tempo.
- As entradas antigas do histórico foram gravadas sem origem: ao mostrar, o app junta-a (`AlertEntry.displayMessage`); os dados guardados não mudaram.

**Avisos simulados**
- "Testar avisos" e "Testar confetti" usam um PR real da lista para mostrar a etiqueta na linha, mas NÃO são gravados nos "não vistos" (`sampleIDs`).

> [!bug] Corrigido a 27/out
> Até 27/out um aviso de teste ficou gravado e fazia o 2493 aparecer como "aprovado". Foi corrigido e a entrada falsa foi apagada.

**O que avisar**
- Avisam SEMPRE: review pedido, CI, aprovações, alterações pedidas, conflitos.
- Configuráveis: comentários e menções (`alertComments`, ligado), merged (ligado), Jira (ligado), fechado/left (`alertOnClose`, desligado).

**Não incomodar** — silencia SOM e NOTIFICAÇÕES (não os canais visuais). Ativo por:
- "silenciar agora" manual (também no menu da barra);
- horário silencioso (22:00–08:00 por defeito, desligado; janela pode cruzar a meia-noite; início = fim → sem janela);
- Focus do macOS (default ligado; lê `~/Library/DoNotDisturb/DB/Assertions.json`; precisa de Acesso Total ao Disco, senão nunca deteta).

**Não vistos**: até 40, persistidos; limpos ao fechar a ilha depois de aberta.

**Histórico de avisos** (`AlertLog`)
- 30 dias, máx. 300, mais recentes primeiro. O mesmo alerta (mesmo PR + tipo) repetido nas últimas 12h não duplica.
- Só PRs e Jira (offline/online, nova sessão e briefing nunca entram). Entradas de tipos antigos removidos são ignoradas ao ler.
- Filtro por origem (Tudo / PRs / Jira); clicar abre o PR/task.
- Acesso: menu da barra "Histórico de avisos…", Definições, bloco "Avisos recentes" ("ver tudo").

**Cópia de segurança do histórico** (`HistorySyncStore`, `HistorySync`; Definições → Histórico → "Guardar em")
- O histórico fica sempre neste Mac (UserDefaults); a cópia só acrescenta. Uma falha de sincronização mostra o erro na página e no registo de erros, sem perder nada.
- **Gist do GitHub** (default): gist secreto `dr-island-sync.json` na conta do `gh` (sem tokens na app; precisa do scope `gist`). No arranque procura um gist com esse ficheiro; se não houver, cria-o. O id e a conta ficam guardados; se o `gh` mudar de conta, procura de novo. Secreto = não listado: quem tiver o link consegue abri-lo.
- **OneDrive**: pasta `Dr Island` dentro de `~/Library/CloudStorage/OneDrive-…` (a da empresa antes da pessoal), um ficheiro por Mac (`dr-island-historico-<nome-do-mac>.json`), por isso o OneDrive nunca cria cópias de conflito. Lê e junta os ficheiros de todos os Macs. Se a pasta não existir, a opção aparece como "não encontrado" e não pode ser escolhida.
- **Só neste Mac**: pede confirmação ("sem cópia de segurança"); a cópia que já existia não é apagada.
- Sincroniza ~8s após o arranque, 5s depois de cada novo aviso (junta vários) e a cada 15 min; botão "Sincronizar agora" e "Abrir gist"/"Mostrar pasta".
- Junção: união por id, mais recentes primeiro, mesmos limites (30 dias, 300). "Limpar histórico…" grava a data da limpeza (`historyClearedAt`), que viaja com a cópia: as entradas até essa data desaparecem em todos os Macs.

**Definições no gist** (`settingsSyncEnabled`, default ligado; só com a cópia em «Gist do GitHub»)
- Ficheiro `dr-island-settings.json` no mesmo gist secreto do histórico, com a data da última alteração, o Mac e os valores (`SettingsBackup`, DrIslandCore).
- Vão todas as preferências com default em `Settings.registerDefaults()`, menos (`SyncedSettings.excluded`): caminho do `gh`, ecrãs (todos/desligados/ecrã da ilha), ajuste do notch, calibração interna do uso, o histórico e a sua configuração, a contabilidade desta sincronização, «silenciar agora», estado do resumo do dia, timer a correr e uso diário. O token do Jira nunca vai (só está na Keychain).
- Regras (`SettingsSync`): ganha a alteração mais recente (`settingsChangedAt`, carimbada ~2 s depois de uma preferência mudar neste Mac); um Mac que nunca sincronizou as definições (`settingsSyncedOnce`) adota as do gist; só se aplicam chaves conhecidas e do mesmo tipo; o que vem do gist não conta como alteração local.
- Sincroniza com o histórico (arranque, 15 min, "Sincronizar agora") e 5 s depois de uma alteração. Uma falha aparece à parte em Definições → Histórico e no registo de erros, sem afetar o histórico.

**Offline/online**: a borda fica vermelha sem rede (`NetworkMonitor`); a mini ilha avisa "Sem ligação à internet" / "Ligação restabelecida"; ao voltar a rede (após 2s) atualiza tudo.

**Logo na ilha**: o logo da Doutor Finanças aparece pequeno, a branco (60 % de opacidade) no canto superior esquerdo da ilha aberta, à altura do notch, como marca de água (`IslandView.watermark`), sem interceptar cliques.

**Splash no arranque**: ~1s depois de abrir, a mini ilha mostra o logo da Doutor Finanças (`Resources/DoutorFinancasLogo.svg`, copiado pelo `bundle.sh`; fora do `.app` não aparece), mesmo com o banner de avisos desligado. O logo surge de um desfoque com escala em mola e um brilho atravessa-o uma vez (`SplashLogo`; com Reduzir movimento, só um fade). A borda do notch e os pontos de atenção/novidades/sincronização só aparecem depois do splash terminar (`IslandState.splashPending`; se o splash não chegar a tocar, são libertados ao fim de 8s). Nos primeiros 15s após o arranque, as mudanças de rede não abrem a mini ilha ("Offline"/"Online"), mas a borda vermelha e o refresh ao voltar a rede mantêm-se.

### 8. Resumo do dia e linha do tempo

**Linha do tempo** (bloco, `showTimeline` ligado)
- Eventos de hoje por ordem cronológica.
- Gráfico de eventos por hora em colunas (`HourlyColumnChart`, também em Definições → Dia): intervalo desde a 1ª atividade ou 08h, mínimo 6h, até à hora atual. Horas sem eventos ficam com um traço discreto; a coluna mais alta mostra o número; a hora atual aparece como «agora». Passar o rato numa coluna diz a hora e o total. Hora de pico = a mais cedo em caso de empate.
- "detalhes" abre Definições → Dia, com seletor de dia (30 dias) e "Em números".

**Resumo/briefing**
- Enquanto o resumo está ativo, o bloco "Avisos recentes" fica escondido (mostraria as mesmas linhas).
- Digest do que mudou desde a última vez que viste a ilha (`briefingLastSeen`; sem isso, 24h atrás).
- Abre sozinho no máximo 1×/dia, a partir das 05:00, só se houver algo novo e `briefingAuto` ligado (default).
- Anunciado na mini ilha ("Resumo do dia: 3 PRs · 2 Jira"); o bloco completo aparece na abertura seguinte até "ok" (marca como visto).
- Etiquetas: "Desde as 09:30", "Desde ontem · 18:12", "Desde 12 out · 18:12". O botão "resumo" mostra-o manualmente.

### 9. Layout e aparência

**Colunas e blocos**
- 1–3 colunas simétricas em torno do notch (largura Normal 400 / 660 / 870 pt, Compacto 340 / 560 / 740 pt; ajuste extra por coluna −60…+120 pt). Predefinições: vertical (1 col), duas colunas, três colunas.
- Cada bloco move-se de coluna ou posição e aparece exatamente 1×: repetido mantém o 1º; em falta vai para o fim da 1ª coluna; ao reduzir colunas, os blocos passam para a última mantida.
- Blocos sem conteúdo ou desligados não ocupam espaço. Altura = coluna mais alta.
- Sem linha divisória entre colunas. Uma coluna mais alta do que o máximo faz scroll e desvanece no fundo (fade) em vez de ser cortada; começa sempre pelo topo.

**Layout «Camadas»**
- Cada bloco é um card com fundo, borda fina, brilho no topo e um cabeçalho com um quadrado colorido da fonte (Claude laranja, Git roxo, Jira/Sprint/Backlog/Histórico/Linha do tempo azul, Foco verde, Música rosa, Avisos/Resumo âmbar).
- Cabeçalho da ilha na faixa do notch: com 2+ colunas em Normal, a saudação («Bom dia» 05–11h, «Boa tarde» 12–19h, «Boa noite» no resto) e a data.
- Linhas de PR e de task com uma segunda linha de detalhes em Normal (repositório e autor; tipo e responsável ou prioridade) e o estado num pill colorido pela categoria. O dono aparece como avatar com as iniciais e uma cor estável por nome.
- **Abas nos cards Git e Jira**: Git «Meus N» / «A rever N»; Jira «Tasks N» / «Aprovações N». O card da Sprint não tem abas: mostra «As minhas · N» e «Aprovações · N» uma por baixo da outra, com os totais reais. Só há abas quando a 2.ª lista está ligada e as duas têm conteúdo; senão o card mostra uma só lista. Ao abrir a ilha, muda para a outra aba se a atual não tiver itens e a outra tiver, ou se a outra tiver novidades por ver e a atual não tiver nenhuma (`TabChoice`, DrIslandCore). As novidades por aba seguem o canal «linha destacada» dos avisos.
- Tudo o que é desenhado sobre o preto do notch (mini ilha, borda, pontos) usa cores para fundo escuro, mesmo no tema Claro.

**Estilo: Camadas ou Bento** (Definições → Aparência → «Tema e tamanho» → «Estilo»; `islandStyle`, default Camadas)
- **Camadas**: os blocos nas colunas escolhidas em «Layout».
- **Bento**: em cima, números grandes (`KPITile`): Claude (% da sessão, reinicia em, barra e, à direita, «Semana N%» na cor do limiar, com «Mostrar semana» ligado; o tooltip diz quando a semana reinicia), Pull requests (abertos, teus · a rever, barra dividida), Sprint (dia X / Y dias, tuas · aprovações, progresso) e Foco (tempo, ronda, pontos; clicar começa/pausa). Com 3 colunas juntam-se Jira (tasks, aprovações) e Avisos (eventos de hoje, clicar abre o histórico). 1 coluna: grelha 2×2; 2: uma linha de 4; 3: uma linha de 6. Fontes desligadas saem da faixa. Em Compacto cada número fica numa linha (ícone e valor; o Claude junta «semana N%» à direita).
- Por baixo, as listas: os blocos do layout menos os que estão noutro sítio (Claude e Foco nos números, Música no dock, Avisos na faixa com menos de 3 colunas), redistribuídos pelas colunas para equilibrar as alturas (`BentoLayout`, DrIslandCore).
- Faixa de avisos ao fundo (menos de 3 colunas; escondida com o Resumo do dia ativo): os últimos avisos lado a lado (4, ou 2 com 1 coluna), com origem e há quanto tempo; em Compacto, uma linha com o último.
- Música no dock, quando há algo a tocar: capa, título, «a tocar» e play/pausa.
- Largura: 1 coluna 400 pt (Compacto 340), 2 colunas 780 (620), 3 colunas 960 (800). `DR_ISLAND_STYLE=camadas|bento` força o estilo num arranque.
- O logótipo da Doutor Finanças fica no canto inferior direito, ao lado do dock (nos dois estilos).

**Temas** (Definições → Aparência → «Tema e tamanho», miniaturas)
- Grafite (default, as cores originais), Meia-noite (gradiente azul-escuro), Aurora (dois brilhos, violeta e verde-azulado) e Claro (fundo claro com uma faixa preta de altura notch + 6 pt, para se fundir com o notch; cabeçalho em branco).
- A mini ilha e a borda do notch continuam pretas em todos os temas; só as cores de destaque seguem o tema.
- «Aumentar contraste» do macOS aproxima os textos secundários do principal e reforça bordas e cards; «Reduzir transparência» torna os cards opacos e tira os brilhos da Aurora (`IslandPalette.adjusted`).

**Tamanho: Normal e Compacto**
- Compacto: cards mais pequenos (cantos 12 pt, padding 9), linhas de uma só linha (22 pt, sem detalhes), anel do Claude de 52 pt, ícones do dock de 22 pt, texto 11,5 pt; nunca fica mais alto do que a ilha antiga.
- Escolha manual em «Tema e tamanho» e atalho global opcional «Atalho para alternar o tamanho» (desligado por defeito; mesmas opções do atalho principal). Os dois atalhos não podem ser iguais: o seletor desativa a combinação do outro e, se coincidirem, ganha o de abrir a ilha.

**Hover e atalho**
- `expandOnHover` ligado; atraso ao fechar 0–1s (default 0,2).
- Atalho global (Carbon hot key, sem Acessibilidade) abre/fecha no ecrã do rato. Opções: desligado, ⌃⌥I (default), ⌃⌥Espaço, ⌥⌘I.

**Efeitos abrir/fechar**: Mola (default), Génio (lamp), Gota, Dissolver, Dobradiça, Fenda. Velocidade 0,5–3× (default 1,6), elasticidade 0–1 (default 0,55); botão de pré-visualização nas Definições.

**Notch e ecrãs**
- Medida detetada do sistema (`safeAreaInsets` + áreas auxiliares, com desvio do centro). Ajuste fino: largura ±20pt, altura ±10pt (só em notch real).
- Ecrãs: "Com notch (automático)" ou "Principal"; mostrar em todos os ecrãs ligado, com opção de desligar ecrãs individuais.
- Esconde a borda/ilha quando uma app está em ecrã inteiro nesse ecrã (deteção do Space de tipo 4 via CoreGraphics privada; se falhar, não esconde nada).
- Ícone de sincronização (à esquerda do notch) enquanto há refresh.

> [!bug] Corrigido: vista da ilha recriada no ecrã com notch
> No ecrã com notch o macOS arredonda a origem da janela (260,0 em vez de 260,5, por causa do desvio de 0,5 pt do notch) e `IslandInstance.update` comparava a moldura ao ponto exato. Resultado: RECRIAVA a vista da ilha a cada alteração de definições (o app grava definições a cada leitura de uso), apagando animações a meio. O monitor secundário (posição inteira) não era afetado, por isso o brilho só corria nele. Corrigido com tolerância de 1 pt (`CGRect.isClose`). Provável causa também de mini ilhas/animações cortadas no ecrã do notch. Medido: antes `frameEq=false` no ecrã integrado; depois só 1 criação por ecrã.

**Barra de menu**
- Ícone gauge; texto opcional com a % da sessão (ou o tempo do foco).
- Menu: 4 linhas de resumo (Sessão % · reinicia em; Semana %; PRs: N meus · N a rever; Jira: N tasks, N a aprovar), Atualizar agora (⌘R), Silenciar avisos (toggle), Acerca, Histórico de avisos…, Gestão…, Definições… (⌘,), Registo de erros…, Reiniciar, Sair (⌘Q).
- `showIsland=false` → só barra de menu. Arrancar no login em Definições → Geral.

**Páginas das Definições**: Geral, Aparência, Conteúdo, Layout, Claude, Custo, GitHub, Jira, Atalhos, Avisos, Histórico/Dia, Registo, Acerca.

### 10. Marca de dono nas linhas

- Avatar redondo no FIM de cada linha de PR e de task, com uma cor estável por nome (`AvatarColor`).
- Só nas linhas dos outros: as iniciais do autor/responsável (cinzento). Quando é meu não aparece nada.
- Iniciais: nome com 2+ palavras → primeira e última (Luís Pedro Bettencourt Costa → LC); uma só palavra/login → 2 primeiras letras (luisinhoc → LU).
- Dica ao passar o rato: o nome completo.
- Definição `showOwner` (default ligado) em Definições → Conteúdo → "Dono nas linhas".
- Útil sobretudo nas Reviews e Aprovações, onde as linhas são de outras pessoas.
- Lógica em `Owner` (DrIslandCore).

### 11. Gestão (2.ª página da ilha)

- A ilha tem **duas páginas**: o resumo habitual e a «Gestão». Passa-se de uma à outra com um **deslize horizontal de dois dedos** no touchpad (só com a ilha aberta e o rato por cima; a ilha acompanha o dedo e a altura anima entre as duas), pelo **botão de gráficos no topo da ilha** (`chart.line.uptrend.xyaxis`, ao lado de reiniciar e das definições; fica azul na «Gestão» e volta ao resumo), pelos **dois pontinhos** no fundo (clicáveis) ou pelo botão (`chart.xyaxis.line`, tooltip «Gestão») no título do card da sprint. Passa de página com 1/3 da largura ou um gesto rápido (`PageSwipe`, DrIslandCore); movimento vertical e rodas de rato nunca mudam de página. Com «Reduzir movimento» a troca é um fade. Ao fechar, a ilha volta ao resumo. Não há janela nem item de menu. Definições → Jira → «Gestão» (`showManagement`, default ligado) esconde a página: sem deslize, sem pontinhos e sem o botão no card da sprint. O botão de gráficos do topo continua visível e, clicado, volta a ligar a página e abre-a.
- **Indicador «ao vivo»** no topo da ilha, como no exemplo de design: ponto verde «ao vivo» com os dados a atualizar; ponto vermelho «sem ligação» sem rede ou com o Claude offline (as mesmas regras da borda vermelha).
- `ManagementStore` lê tudo do Jira em **só leitura** (GET). Lê quando a página abre (e de cada vez que se volta a ela), mantendo o gráfico visível enquanto atualiza.
- **Velocidade das leituras** (medido com `DR_ISLAND_JIRA_TRACE=1`: cada pedido ao Jira demora ~200 ms, o peso estava no número de pedidos feitos um a um, não num limite do Jira):
  - Os quadros, os campos (`fetchFieldIDs`: Sprint e pontos numa só leitura de `/field`) e os estados (`/status`) são pedidos ao mesmo tempo; campos e estados só na primeira abertura da sessão, e os estados passam a cada leitura de sprint em vez de cada sprint os pedir.
  - O histórico das tasks cuja pesquisa vem cortada é lido 4 de cada vez (`changelogConcurrency`); as sprints fechadas da Velocity, 2 de cada vez.
  - **Sprints fechadas em disco** (`SprintSnapshotFileCache`, `~/Library/Application Support/DrIsland/sprints/v1-<id>.json`): não mudam, por isso a Velocity e o burndown de uma sprint antiga abrem sem ir ao Jira depois da primeira vez.
  - Voltar a uma sprint aberta (‹ ›) nos 2 minutos seguintes mostra-a sem nova leitura; os bugs do mesmo projeto ficam 5 minutos.
  - **A sprint escolhida primeiro**: ao abrir ou ao mudar de stream, só a sprint escolhida é lida (a Velocity mostra logo o que já está em disco); as sprints fechadas que faltam e os bugs só começam quando ela já está no ecrã. Mudar de stream ou de sprint cancela as leituras que estavam a correr (`loadTask`, `ManagementSideData.cancelAll`), para não competirem com as novas. Medido sem cache: sprint no ecrã em ~1,7 s.
  - Medido no Jira da DF: a primeira abertura passou de ~27 s (Velocity completa) para ~6,5 s; as seguintes ficam completas em ~3 s.
- Cabeçalho: abas de **stream** à esquerda (as escolhidas nas Definições, ou as das sprints onde já tive tasks), ‹ nome › da sprint (abre na ativa; também as fechadas) e abas **Pontos | Tasks** à direita, no mesmo estilo das abas dos cards. Sem campo de pontos no site, a unidade fica em «tasks».
- **Números da sprint** (`ManagementKPIs`, os mesmos tiles do Bento; uma linha de 4, ou 2×2 com 1 coluna; em Compacto, título e valor numa linha): **Concluído** (% e «N de M pts», barra verde), **Faltam** (dias úteis até ao fim, «acaba a dd/mm», barra azul com a parte da sprint já passada), **Ritmo** («N pts atrás» a âmbar ou «à frente» a verde face à linha ideal de hoje, ou «em dia», com a previsão por baixo) e **Bloqueadas** (abertas com flag, a vermelho, e a primeira com os dias). As contas vêm de `SprintPace` (DrIslandCore): ritmo = feito ÷ dias úteis passados; previsão = o que falta − ritmo × dias úteis que faltam (sem previsão depois do fim).
- **Quatro cartões** (grelha 2×2 quando a ilha tem 2 ou 3 colunas, empilhados e com scroll vertical numa coluna só; cada um tem a mesma altura). Todos usam o card do resto da ilha (`ManagementCardFrame`): tile azul do Jira, título, legenda à direita do cabeçalho (`ChartKey`) e pills de resumo presas ao fundo (`Pill`):
  - **Burndown**: o gráfico cobre a sprint inteira (até ao último dia), com os dias que faltam sombreados. «Por fazer» (azul, linha de 2 pt com uma área suave por baixo e o valor atual num ponto), ideal tracejado fino até 0 no último dia (dias úteis), âmbito (cinza, em degraus), «hoje» numa pill âmbar e a **previsão** tracejada desde hoje até ao fim, com «~N» na ponta. O eixo vai até ao primeiro valor redondo acima dos dados (`ChartScale`: 33 pontos → 0–40). Passar o rato mostra os três valores do dia ao lado do ponto. Pills: «62% concluído», «previsão: sobram ~N pts» (âmbar) ou «previsão: acaba a tempo» (verde), «+N pts de âmbito» quando entrou trabalho depois do início e, em pontos, «N de M tasks sem pontos» (clicar passa a tasks) quando falta pontos a mais de 20 %.
  - **Fluxo** (`FlowMetrics`, `FlowGroup`): uma **barra segmentada** com os três grupos de estado (por fazer, em curso, concluído), cada parte com o total lá dentro, e por baixo (só em Normal) o nome, o total e a média das **medianas de dias** que o trabalho fica nos estados do grupo (das estadias já terminadas). Depois, «Paradas há mais tempo · N» com as tasks **bloqueadas (flag) ou paradas há ≥ 3 dias** no mesmo estado, as bloqueadas primeiro, como linhas de lista (ícone, chave, estado e pill de dias), quantas couberem no card. Os estados vêm do Jira por id (`/rest/api/3/status`), com o nome.
  - **Bugs · 8 semanas** (`BugFlow`, `BugsClient`): em **espelho**, criados para cima (vermelho) e resolvidos para baixo (azul: vermelho contra verde confunde-se com daltonismo) na mesma escala, por semana; ao passar o rato, os números e o saldo da semana (semanas a começar à segunda), «N abertos» (com «+» se houver mais do que os 100 lidos), totais e mediana de dias até resolver. São os bugs de **todo o projeto** da sprint (o prefixo das chaves), pelos tipos que `JiraIssueKind` reconhece como bug; lê até 200 recentes e 100 abertos.
  - **Velocity** (`VelocityMetrics`): por sprint fechada do board (até 6, a mais antiga à esquerda), planeado (o que estava na sprint ao começar, barra larga e discreta) contra concluído (barra fina azul por dentro), com a média como linha fina e a etiqueta «média N» à direita; a última sprint fica em destaque no eixo e mostra o valor. Pills: média, número de sprints e «cumpre N% do plano». Passar o rato numa sprint mostra o planeado, o concluído e a percentagem cumprida. As sprints fechadas são lidas uma vez por sessão (em memória) e o gráfico vai enchendo à medida que chegam.
- Estados: «A carregar…», erro em português (mantém o último gráfico), «Sem boards», «Sem sprints neste board», «Sem tasks nesta sprint», «Sem pontos nesta sprint».
- Teste sem Jira: `DR_ISLAND_FAKE_MANAGEMENT=1` com `DR_ISLAND_PAGE=management` e `DR_ISLAND_SNAPSHOT=<png>`.

## Avisos/alertas — resumo rápido

Ver [[#7. Avisos (alertas)]] para canais e regras, e a tabela de tons em [[#2. Pull Requests (GitHub)]].

## Definições e defaults (resumo)

| Definição | Default |
|---|---|
| Limiar âmbar / vermelho | 60% / 85% |
| Refresh Claude | 120s (60–600) |
| Refresh GitHub | 120s (60–600) |
| Refresh Jira | 180s (60–900) |
| Limite PRs | 20 (1–50) |
| Máx. tasks Jira | 20 (1–20) |
| Espessura da borda | 3pt (1–8) |
| `showWeekly` | ligado |
| `showForecast` | ligado |
| Estimativa local | ligada |
| `costEnabled` | ligado |
| `showCost` | desligado |
| Bloco Histórico | desligado |
| Jira | desligado |
| `jiraApproverEnabled` | ligado |
| `jiraBacklogEnabled` | ligado |
| `showMusic` | ligado |
| `showFocus` | desligado |
| Foco / curta / longa / rondas | 25 / 5 / 15 / 4 |
| `showTimeline` | ligado |
| `briefingAuto` | ligado |
| `alertComments` / merged / `alertJira` | ligados |
| `alertOnClose` | desligado |
| Horário silencioso | desligado, 22:00–08:00 |
| Focus do macOS | ligado |
| `expandOnHover` | ligado |
| Atraso ao fechar | 0,2s |
| Efeito / velocidade / elasticidade | Mola / 1,6× / 0,55 |
| Atalho global | ⌃⌥I |
| Tema / tamanho / estilo | Grafite / Normal / Camadas |
| Atalho para alternar o tamanho | desligado |
| `alertConfetti` | ligado |
| `showOwner` | ligado |
| `claudeUpdateAnimation` | ligado |
| `claudeNewSessionAnimation` | ligado |

## Persistência e segurança

- Token do Claude: lido do Keychain do Claude Code, nunca guardado nem registado.
- Token do Jira: só no Keychain (`com.fazam.token-island` / `jira-api-token`), com cache em memória.
- GitHub: sem tokens na app; usa o `gh` autenticado.
- UserDefaults: preferências e estado (cache do uso, baselines de PRs/Jira, mutes, estado do foco, não vistos, `briefingLastSeen`). As preferências têm cópia no gist (ver «Definições no gist»).
- Transcripts do Claude Code: só leitura.
- Jira: só https.

## Limitações conhecidas

> [!warning] A ter em conta
> - O endpoint de uso do Claude não é documentado e pode mudar.
> - A app não está notarizada por defeito (1ª abertura: botão direito → Abrir). Sem certificado estável, o macOS esquece a permissão de Acessibilidade a cada build.
> - O Focus requer Acesso Total ao Disco.
> - O Now Playing do sistema depende do helper no `perl`.
> - Os custos são estimativa; preços a confirmar em anthropic.com/pricing.
> - CodeRabbit e a barra "2 humanos + CodeRabbit" são regra específica da equipa.
> - O campo Jira `customfield_10127` é específico desta instância.
> - Cada `scripts/bundle.sh release` muda a assinatura ad-hoc e o macOS pode voltar a pedir a permissão de Acessibilidade do botão de pausa do player.
> - A marca de dono ainda não foi vista no ecrã real (só compilada e testada); o confetti foi validado num snapshot, mas não a correr.
> - O desenho do cometa/brilhos na mini ilha foi validado só no código (o snapshot de teste não apanha animações a meio); a confirmar no ecrã real.
> - A contagem de comentários usa janelas de 30 comentários/reviews/threads por PR; num PR muito comentado (o 2370 tem 41) a contagem dos meus pode ser ligeiramente imprecisa. Se um comentário meu e um de outra pessoa chegam entre duas leituras, o alerta sai (há um de outra pessoa).
> - A regra "2 humanos + CodeRabbit" só conta o CodeRabbit se este der uma review de aprovação (se só comentar, nenhum PR chega a "aprovado").

## Alterações de 27/out/2026

- Briefing do dia anunciado na mini ilha (já não abre a ilha completa; `.briefing`).
- Confetti em PR aprovado/merged + definição `alertConfetti` + botão de teste.
- Regra de aprovação 2 humanos + CodeRabbit calculada no app.
- Linhas "a rever" mostram "aprovaste" até a barra da equipa ser cumprida.
- Correção dos avisos simulados que ficavam gravados.
- Marca de dono (eu/iniciais) no fim da linha.
- Origem nos avisos (GIT/JIRA/…).
- Investigação de travamentos nas Definições sem causa encontrada: uma amostra de 40 s não apanhou nenhum travamento; o único "bloqueio" registado foi o Mac a dormir; o vigia só regista bloqueios >4 s. O possível agravante (recriação da vista a cada alteração de definições) foi corrigido, mas não está provado que fosse a causa.
- Comentários do próprio utilizador já não geram aviso (PRs e Jira).
- Mini ilha: alertas seguidos fundem-se (máx. 4 linhas) em vez de se substituírem.
- Animação de nova sessão também no contorno da mini ilha; a mini ilha abre logo (0,15 s).
- Nova definição `claudeUpdateAnimation` ("Ao atualizar o uso"); estava desligada nas definições do utilizador e foi ligada.
- Bug de ecrãs: vista da ilha recriada a cada alteração de definições no ecrã com notch; corrigido com tolerância de 1 pt.

## Testes e build

- Testes em `Tests/DrIslandCoreTests`: Island effect, comentários/mutes/Jira, LocalUsage, FocusTimer, Shortcuts, UsageHistory, LayoutConfig, Jira, UsageAlerts, QuietHours, NowPlaying, AlertLog, UsageCost, GitHub, UsageClient, PullRequestChanges, DayBriefing.
- `scripts/bundle.sh`: gera `DrIsland.app` (ad-hoc).
- `scripts/dmg.sh`: gera o DMG (versão em `VERSION`); com `CODESIGN_IDENTITY` + `NOTARY_PROFILE` assina e notariza.
- `make-icon.swift`: ícone com a cor da marca `#00A6E5`.
- `swift test` só corre com o toolchain do Xcode: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test` (com as Command Line Tools falta o plugin `TestingMacros`).
- A build da app usa `scripts/bundle.sh release` (SDK 26); `swift build` simples com o SDK 27 falha por falta de `SwiftUIMacros`.
- Testes novos/atualizados: aprovação (2 pessoas + CodeRabbit), autor do PR, iniciais, origem das mensagens, `displayMessage` do histórico, `messagesStartWithTheirOrigin`, comentários próprios ignorados no PR e no Jira, contagem dos comentários próprios.
