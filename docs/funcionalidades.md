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
| Debug | `DR_ISLAND_SNAPSHOT=<png>` grava o render; `DR_ISLAND_FAKE=0..1` força a % |
| Processo | Mantido acordado (`beginActivity`), pois o painel transparente click-through pode ser limitado pelo macOS |

## Features por bloco

1. **Claude (uso)** — medidor de sessão (5h) e semana, previsão de esgotamento, estimativa local, histórico.
2. **Custo e tokens** — hoje / 7 d / 14 d / total, por família de modelo.
3. **Pull requests (GitHub)** — meus, a rever, alterações detetadas, silenciar.
4. **Jira** — tasks próprias, bloco "Aprovações" e card "Backlog" (backlog da equipa por sprint).
5. **Música** — Spotify, Música e Now Playing do sistema.
6. **Foco (Pomodoro)**.
7. **Atalhos de desenvolvimento** — dock de apps.
8. **Avisos** — canais, não incomodar, histórico.
9. **Resumo do dia e linha do tempo**.
10. **Layout e aparência**, barra de menu, atalho global.

Blocos disponíveis no layout: Claude, Pull requests, Jira, Backlog, Foco, Histórico, Música, Avisos recentes, Resumo do dia, Linha do tempo.

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

**Limite semanal diário**: a barra "Semana" está dividida nos 5 dias úteis da janela semanal (20% cada; fins de semana não somam). A marca branca é o que se pode gastar até ao fim de hoje (dias úteis já começados na janela × 20%, mínimo 20%); o que sobra de dias anteriores acumula. A cor usa os mesmos limiares âmbar/vermelho da sessão, aplicados a `uso semanal ÷ permitido até hoje` (`WeeklyPace`). Sem `resets_at`, usa a % semanal simples.

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
- Linha por PR: ícone de CI, aviso de conflitos, ícone de review, `repo#n`, título, tag (alteração não vista ou motivo de atenção), "draft", e no fim a marca de dono (ver [[#10. Marca de dono nas linhas]]).
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
| merged | PR sai da lista, é meu e está nos merged recentes |
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
- Bolinha azul (em curso) ou cinzenta, chave, resumo, ícone de prioridade, tag de estado, tag de alerta e, no fim, a marca de dono (ver [[#10. Marca de dono nas linhas]]). Clique abre `/browse/<KEY>`.
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
- Vazio: "Nada a tocar — Abre uma música para a controlar aqui".

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
- Ícones em alta resolução com magnificação tipo Dock.

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
- **Nova sessão na mini ilha**: com a mini ilha visível (Mini ilha e aviso de nova sessão ligados), o cometa e o brilho verde percorrem o CONTORNO da mini ilha (`miniSessionAnimation`, usa `IslandShape` com `outlineOnly`), os dois brilhos (sparkles) aparecem ao lado dela e a mini ilha abre logo (atraso de 0,15 s em vez de 1,4 s à espera da volta do cometa). Sem mini ilha, continua no anel do notch.

**Origem do aviso**
- Todas as mensagens começam pela origem, no formato `ORIGEM - texto`: `GIT - PR aprovado: repo#n`, `JIRA - Novo comentário em TEP-1`. Outras origens: `CLAUDE` (nova sessão), `REDE` (offline/online), `RESUMO` (briefing, só o título).
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

**Offline/online**: a borda fica vermelha sem rede (`NetworkMonitor`); a mini ilha avisa "Sem ligação à internet" / "Ligação restabelecida"; ao voltar a rede (após 2s) atualiza tudo.

**Splash no arranque**: ~1s depois de abrir, a mini ilha mostra o logo da Doutor Finanças (`Resources/DoutorFinancasLogo.svg`, copiado pelo `bundle.sh`; fora do `.app` não aparece), mesmo com o banner de avisos desligado. Nos primeiros 15s após o arranque, as mudanças de rede não abrem a mini ilha ("Offline"/"Online"), mas a borda vermelha e o refresh ao voltar a rede mantêm-se.

### 8. Resumo do dia e linha do tempo

**Linha do tempo** (bloco, `showTimeline` ligado)
- Eventos de hoje por ordem cronológica.
- Gráfico de eventos por hora: intervalo desde a 1ª atividade ou 08h, mínimo 6h, até à hora atual. Hora de pico = a mais cedo em caso de empate.
- "detalhes" abre Definições → Dia, com seletor de dia (30 dias) e "Em números".

**Resumo/briefing**
- Digest do que mudou desde a última vez que viste a ilha (`briefingLastSeen`; sem isso, 24h atrás).
- Abre sozinho no máximo 1×/dia, a partir das 05:00, só se houver algo novo e `briefingAuto` ligado (default).
- Anunciado na mini ilha ("Resumo do dia: 3 PRs · 2 Jira"); o bloco completo aparece na abertura seguinte até "ok" (marca como visto).
- Etiquetas: "Desde as 09:30", "Desde ontem · 18:12", "Desde 12 out · 18:12". O botão "resumo" mostra-o manualmente.

### 9. Layout e aparência

**Colunas e blocos**
- 1–3 colunas simétricas em torno do notch (largura 400 / 660 / 870 pt; ajuste extra por coluna −60…+120 pt). Predefinições: vertical (1 col), duas colunas, três colunas.
- Cada bloco move-se de coluna ou posição e aparece exatamente 1×: repetido mantém o 1º; em falta vai para o fim da 1ª coluna; ao reduzir colunas, os blocos passam para a última mantida.
- Blocos sem conteúdo ou desligados não ocupam espaço. Altura = coluna mais alta.

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
- Menu: 4 linhas de resumo (Sessão % · reinicia em; Semana %; PRs: N meus · N a rever; Jira: N tasks, N a aprovar), Atualizar agora (⌘R), Silenciar avisos (toggle), Acerca, Histórico de avisos…, Definições… (⌘,), Registo de erros…, Reiniciar, Sair (⌘Q).
- `showIsland=false` → só barra de menu. Arrancar no login em Definições → Geral.

**Páginas das Definições**: Geral, Aparência, Conteúdo, Layout, Claude, Custo, GitHub, Jira, Atalhos, Avisos, Histórico/Dia, Registo, Acerca.

### 10. Marca de dono nas linhas

- Cápsula no FIM de cada linha de PR e de task.
- "eu" (azul) quando é meu; caso contrário, as iniciais do autor/responsável (cinzento).
- Iniciais: nome com 2+ palavras → primeira e última (Luís Pedro Bettencourt Costa → LC); uma só palavra/login → 2 primeiras letras (luisinhoc → LU).
- Dica ao passar o rato: "Teu" ou o nome completo.
- Definição `showOwner` (default ligado) em Definições → Conteúdo → "Dono nas linhas".
- Útil sobretudo nas Reviews e Aprovações, onde as linhas são de outras pessoas.
- Lógica em `Owner` (DrIslandCore).

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
| `alertConfetti` | ligado |
| `showOwner` | ligado |
| `claudeUpdateAnimation` | ligado |
| `claudeNewSessionAnimation` | ligado |

## Persistência e segurança

- Token do Claude: lido do Keychain do Claude Code, nunca guardado nem registado.
- Token do Jira: só no Keychain (`com.fazam.token-island` / `jira-api-token`), com cache em memória.
- GitHub: sem tokens na app; usa o `gh` autenticado.
- UserDefaults: apenas números/estado (cache do uso, baselines de PRs/Jira, mutes, estado do foco, não vistos, `briefingLastSeen`).
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
