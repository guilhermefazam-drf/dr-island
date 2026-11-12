# Gráficos do Jira para managers — Fase 1 (burndown) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Uma janela «Gestão» que desenha o burndown de uma sprint (do board escolhido), lido do Jira com histórico, com seletor de pontos/tasks.

**Architecture:** `DrIslandCore` ganha o modelo de uma sprint (`SprintSnapshot`), o parser do changelog, o cálculo puro do burndown e o leitor (`JiraClient` só com GET). `DrIsland` ganha `ManagementStore` e a janela `ManagementView` (Swift Charts). A cache é só uma interface (`SprintMetricsCache`) com implementação nula; a cache em disco é a Fase 2.

**Tech Stack:** Swift 5.9 (modo Swift 5, `StrictConcurrency`), SwiftUI + Charts (framework do sistema, macOS 14+), Swift Testing. Sem dependências externas.

**Spec:** `docs/superpowers/specs/2026-10-30-jira-manager-charts-design.md`

Este plano cobre só o passo 1 da «Ordem de construção» da spec. Os passos 2 (cache em disco), 3 (gráficos 2, 3 e 4) e 4 (exportação) terão planos próprios, escritos depois de esta fase estar a funcionar e de se ter validado a leitura do histórico no Jira real.

## Global Constraints

- **Jira só de leitura:** nada novo faz pedidos que não sejam GET; todos passam por `JiraClient.get` (que chama `requireReadOnly`).
- macOS 14+; **sem dependências externas** (Charts é do sistema).
- Código e comentários em inglês; texto da UI e docs em português europeu.
- Testes em Swift Testing (`import Testing`, `@Suite`, `@Test`, `#expect`) no alvo `DrIslandCoreTests`; a lógica nova vive em `DrIslandCore`.
- Build da app só com `scripts/bundle.sh release`; testes com `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`.
- Campo de pontos descoberto por nome («Story Points» ou «Story point estimate»), nunca fixo; campo Sprint pelo id já descoberto (`SprintJQL.field(_:)` dá `cf[N]` no JQL).
- Unidade: pontos por defeito, ou nº de tasks; aviso quando faltam pontos em muitas tasks (limiar `Burndown.missingPointsWarning = 0.2`).
- `docs/funcionalidades.md` é atualizado no mesmo commit da funcionalidade.
- Commits **sem** linha `Co-Authored-By` (instrução do utilizador); nada sob `docs/` entra nos commits.

## Review Focus

Entradas que a spec sugere mas nenhuma tarefa exercita por si só; cada uma tem o teste na tarefa dona (entre parênteses).

1. Task retirada da sprint a meio (já não é membro hoje, mas era): conta enquanto lá esteve (Task 2).
2. Task criada diretamente na sprint, sem evento de sprint anterior, e task que transita de outra sprint (campo `from` com vários ids) (Task 1 e 2).
3. Changelog truncado numa task com muitas alterações: o leitor completa-o e o cálculo vê todos os eventos (Task 3).
4. Sprint passada do fim planeado e ainda ativa («fora de prazo»), e sprint sem tasks: o gráfico não falha (Task 2).
5. Pontos alterados a meio da sprint e tasks sem pontos: o burndown usa o valor do dia e o aviso de pontos em falta aparece (Task 2).

---

## File Structure

| Ficheiro | Responsabilidade |
|---|---|
| `Sources/DrIslandCore/SprintMetrics.swift` (novo) | Modelo: `SprintRecord`, `SprintIssue`, `SprintIssueEvent`, `SprintSnapshot`, `MetricUnit`; `SprintMetricsCache` e `NoSprintMetricsCache` |
| `Sources/DrIslandCore/ChangelogParser.swift` (novo) | JSON do Jira → `SprintIssue` com eventos datados |
| `Sources/DrIslandCore/Burndown.swift` (novo) | Cálculo puro: `Burndown.compute(...)` → `BurndownResult` |
| `Sources/DrIslandCore/SprintMetricsClient.swift` (novo) | `extension JiraClient`: sprints do board, snapshot da sprint, categorias de estado, campo de pontos |
| `Sources/DrIsland/ManagementStore.swift` (novo) | `@MainActor @Observable`: boards, sprints, snapshot, unidade, estado |
| `Sources/DrIsland/ManagementView.swift` (novo) | A janela: seletores, gráfico, resumo |
| `Sources/DrIsland/AppDelegate.swift` | Janela «Gestão…», item do menu, observador do pedido de abertura |
| `Sources/DrIsland/IslandView.swift`, `CardTitle.swift` | Botão «Gestão» no card da sprint |
| `Tests/DrIslandCoreTests/…` | Um ficheiro de testes por ficheiro novo do Core |
| `docs/funcionalidades.md` | Secção «Gestão» |

---

### Task 1: Modelo e parser do changelog

**Files:**
- Create: `Sources/DrIslandCore/SprintMetrics.swift`, `Sources/DrIslandCore/ChangelogParser.swift`
- Test: `Tests/DrIslandCoreTests/ChangelogParserTests.swift`

**Interfaces:**
- Produces:
  - `public struct SprintRecord: Codable, Equatable, Sendable { id: Int; name: String; boardID: Int; start: Date?; end: Date?; state: String; completedAt: Date? }` (`state` = `"active"|"closed"|"future"`)
  - `public struct SprintIssueEvent: Codable, Equatable, Sendable { enum Kind: String, Codable, Sendable { case status, sprint, points }; date: Date; kind: Kind; from: String?; to: String? }` (`from`/`to`: nome do estado; ids de sprint separados por vírgula; ou o valor dos pontos como texto)
  - `public struct SprintIssue: Codable, Equatable, Sendable { key: String; type: String?; points: Double?; status: String; isFlagged: Bool; created: Date; resolved: Date?; events: [SprintIssueEvent] }` (`events` por ordem cronológica)
  - `public struct SprintSnapshot: Codable, Equatable, Sendable { sprint: SprintRecord; issues: [SprintIssue]; statusCategories: [String: String]; fetchedAt: Date }` (`statusCategories`: nome do estado → `"new"|"indeterminate"|"done"`)
  - `public enum MetricUnit: String, Sendable { case points, tasks }`
  - `public enum ChangelogParser { static func issues(from data: Data, sprintField: String, pointsField: String?) throws -> (issues: [SprintIssue], truncated: [String], nextPageToken: String?) }` — `truncated`: chaves de tasks em que `changelog.total` excede os `histories` devolvidos; `static func events(fromHistories: [[String: Any]], pointsFieldName: String?) -> [SprintIssueEvent]` (reutilizada na Task 3 para completar o histórico)

- [ ] **Step 1: Escrever os testes que falham** em `ChangelogParserTests.swift`, com um JSON de exemplo (`search/jql` com `expand=changelog`) de duas tasks:
  - `parsesStatusSprintAndPointsEvents`: a task `A-1` tem histórico com `status` («Por fazer» → «Em curso»), `Sprint` (`from: "7351"`, `to: "7351, 7648"`) e `Story Points` (`fromString: "2"`, `toString: "5"`); esperar 3 eventos, por ordem de data, com `kind` `.status`, `.sprint`, `.points` e `from`/`to` exatos (`"7351"` → `"7351, 7648"`).
  - `ignoresUnknownFieldsAndSortsByDate`: um item `field: "assignee"` é ignorado; eventos desordenados saem ordenados.
  - `readsPointsFlagAndDates`: `points == 5`, `isFlagged == true` quando `customfield_10006` é lista não vazia, `created` e `resolved` lidos do ISO 8601 com milissegundos e fuso `+0000`.
  - `reportsTruncatedChangelog`: `changelog: {total: 130, histories: [100 itens]}` → `truncated == ["A-1"]`.
  - `returnsNextPageToken`: `nextPageToken: "abc"` → `"abc"`.
  - `taskCreatedDirectlyInSprintHasSprintEventFromEmpty`: evento `Sprint` com `from: ""` e `to: "7648"` → `from == nil` (vazio vira `nil`).

- [ ] **Step 2: Correr e ver falhar** — `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter ChangelogParserTests` → erro de compilação (tipos por definir).

- [ ] **Step 3: Implementar** os tipos de `SprintMetrics.swift` e `ChangelogParser` com as assinaturas acima. Datas com `SprintParser.parseDate` (já existe). O nome do campo de pontos chega como `pointsFieldName` (ex.: «Story Points») para casar com `items[].field`; o valor atual dos pontos vem de `fields[pointsField]` (id). Estado atual = `fields.status.name`; tipo = `fields.issuetype.name`.

- [ ] **Step 4: Correr e ver passar** — mesmo comando → todos passam.

- [ ] **Step 5: Commit** — `feat(management): sprint snapshot model and changelog parser`.

---

### Task 2: Cálculo do burndown

**Files:**
- Create: `Sources/DrIslandCore/Burndown.swift`
- Test: `Tests/DrIslandCoreTests/BurndownTests.swift`

**Interfaces:**
- Consumes: `SprintSnapshot`, `SprintIssue`, `SprintIssueEvent`, `MetricUnit` (Task 1).
- Produces:
  - `public struct BurndownPoint: Equatable, Sendable { date: Date; remaining: Double; scope: Double; ideal: Double }` (um por dia, até ao dia de `now` ou ao último dia da sprint)
  - `public struct BurndownResult: Equatable, Sendable { points: [BurndownPoint]; plannedScope: Double; doneShare: Double; flaggedOpen: Int; daysLeft: Int; isOverdue: Bool; missingPointsShare: Double; showsMissingPointsWarning: Bool }`
  - `public enum Burndown { static let missingPointsWarning = 0.2; static func compute(_ snapshot: SprintSnapshot, unit: MetricUnit, now: Date, calendar: Calendar) -> BurndownResult }`

Regras (da spec): pertença à sprint em cada instante a partir dos eventos `sprint` (sem eventos de sprint → membro desde o início; com eventos, o estado inicial é «membro» se o `from` do primeiro evento contém o id da sprint); estado em cada instante a partir dos eventos `status` (inicial = `from` do primeiro evento, ou o estado atual se não há eventos); pontos em cada instante a partir dos eventos `points` (inicial idem); «feito» = categoria `done` em `statusCategories` (estado desconhecido conta como `indeterminate`); `remaining` de um dia = soma, ao fim desse dia, do peso das tasks membros e não feitas; `scope` = soma das membros; `plannedScope` = scope no instante `sprint.start`; linha ideal linear em **dias úteis** (seg–sex) de `plannedScope` a 0 em `sprint.end`; sprint não fechada com `now > end` → `isOverdue` e os pontos continuam até `now`; `daysLeft` = dias de calendário até `end`, nunca negativo; `doneShare = 1 - remaining/scope` hoje (0 se scope 0); `missingPointsShare` = tasks membros hoje sem pontos (nil ou 0) a dividir pelas membros (0 se nenhuma), usada só com `.points`.

- [ ] **Step 1: Escrever os testes que falham**, com snapshots construídos à mão (sprint de 2026-10-12 a 2026-10-23, calendário UTC):
  - `remainingDropsWhenATaskGetsDone`: 2 tasks de 3 pontos, uma passa a «Feito» (categoria `done`) a 15/out → `remaining` 6 até 14/out e 3 a partir de 15/out; `doneShare == 0.5` ao fim.
  - `idealLineIsLinearInWorkdays`: `plannedScope == 6`; `ideal` do 1.º dia útil = 6, do último = 0; sábado e domingo repetem o valor da sexta.
  - `taskRemovedMidSprintCountsWhileItWasThere` (Review Focus 1): evento `sprint` com `to` sem o id a 16/out → entra no `scope` até 15/out e sai a partir de 16/out.
  - `taskAddedMidSprintRaisesScopeNotPlanned` : evento `sprint` com `to` a incluir o id a 14/out → `scope` sobe a 14/out, `plannedScope` não.
  - `taskCreatedDirectlyInSprint` e `taskCarriedOverFromAnotherSprint` (Review Focus 2): `from` nulo e `from: "7351"` (outra sprint) — membro só a partir do evento.
  - `pointsEditedMidSprintUsesTheValueOfTheDay` (Review Focus 5): evento `points` 3 → 8 a 15/out → `scope` 3 até 14/out, 8 depois.
  - `unitTasksCountsOnePerIssue`: com `.tasks`, `remaining`/`scope` são contagens.
  - `missingPointsWarning` (Review Focus 5): 2 de 5 tasks sem pontos → `missingPointsShare == 0.4` e `showsMissingPointsWarning == true`; 0 de 5 → `false`; com `.tasks` o aviso é `false`.
  - `overdueActiveSprintKeepsGoingPastTheEnd` (Review Focus 4): sprint `active` com `end` anterior a `now` → `isOverdue == true`, `daysLeft == 0`, último ponto no dia de `now`; sprint `closed` com o mesmo `end` → `isOverdue == false`.
  - `emptySprintDoesNotFail` (Review Focus 4): sem tasks → `points` com zeros, `doneShare == 0`, sem divisão por zero.
  - `flaggedOpenCountsOnlyOpenMembers`: 1 flagged aberta + 1 flagged feita → `flaggedOpen == 1`.

- [ ] **Step 2: Correr e ver falhar** — `swift test --filter BurndownTests` → erro de compilação.

- [ ] **Step 3: Implementar** `Burndown.compute` com as regras acima. Abordagem: para cada dia, avaliar cada task ao fim do dia (`endOfDay` no `calendar` recebido); as funções auxiliares (`isMember`, `statusName`, `points`) são privadas e recebem o instante.

- [ ] **Step 4: Correr e ver passar** — `swift test --filter BurndownTests`.

- [ ] **Step 5: Commit** — `feat(management): burndown calculation`.

---

### Task 3: Leitor (só GET)

**Files:**
- Create: `Sources/DrIslandCore/SprintMetricsClient.swift`
- Test: `Tests/DrIslandCoreTests/SprintMetricsClientTests.swift`

**Interfaces:**
- Consumes: `ChangelogParser` (Task 1), `JiraClient.prepare/get`, `SprintJQL.field(_:)`, `JiraBoard`, `BoardParser`.
- Produces (em `extension JiraClient`):
  - `public func fetchBoardSprints(_ config: JiraConfig, boardID: Int) async throws -> [SprintRecord]` — `GET rest/agile/1.0/board/{id}/sprint?state=active,closed`, paginado por `startAt` até `isLast`; ordenadas por `start` decrescente (sem data no fim)
  - `public func fetchPointsField(_ config: JiraConfig) async throws -> (id: String, name: String)?` — `GET rest/api/3/field`, procura o nome «Story Points» ou «Story point estimate» (por esta ordem)
  - `public func fetchStatusCategories(_ config: JiraConfig) async throws -> [String: String]` — `GET rest/api/3/status`
  - `public func fetchSprintSnapshot(_ config: JiraConfig, sprint: SprintRecord, sprintField: String, points: (id: String, name: String)?) async throws -> SprintSnapshot`
  - `enum SprintMetricsRequests` (interno): `boardSprintsURL(site:boardID:startAt:)`, `sprintIssuesURL(site:sprintID:sprintField:pointsField:pageToken:)`, `changelogURL(site:key:startAt:)`, `static func sprintIssuesJQL(sprintField: String, sprintID: Int) -> String` = `"cf[N] = ID OR cf[N] was ID ORDER BY created ASC"` (via `SprintJQL.field`)

- [ ] **Step 1: Escrever os testes que falham:**
  - `boardSprintsURLAsksForActiveAndClosed`: o URL contém `rest/agile/1.0/board/483/sprint`, `state=active,closed` e `startAt=0`.
  - `issuesJQLIncludesIssuesRemovedFromTheSprint`: `sprintIssuesJQL(sprintField: "customfield_10000", sprintID: 7648) == "cf[10000] = 7648 OR cf[10000] was 7648 ORDER BY created ASC"`.
  - `issuesURLExpandsChangelogAndAsksForTheFields`: `expand=changelog`, `fields` com `status,issuetype,created,resolutiondate`, a flag, o campo de pontos e o campo Sprint; `nextPageToken` só quando dado.
  - `parsesSprintsPage`: JSON de exemplo do agile (`values` com `id`, `name`, `state`, `startDate`, `endDate`, `completeDate`, `originBoardId`, `isLast`) → `SprintRecord` com `boardID` e datas certas; sprint futura sem datas → `start == nil`.
  - `findsThePointsFieldByName`: lista de campos com «Story point estimate» e outro «Story Points» → devolve o de nome «Story Points».
  - `parsesStatusCategories`: `[{name: "Em Progresso", statusCategory: {key: "indeterminate"}}, …]` → mapa nome → chave.
  - `completesATruncatedChangelog` (Review Focus 3): função interna testável `mergeChangelogPages(initial: [[String: Any]], pages: [[[String: Any]]]) -> [[String: Any]]` junta as páginas de `histories` sem duplicar ids.
  - Os testes de pedido reais não existem (sem rede); a garantia de só-leitura já está em `JiraReadOnlyTests`, e o leitor só chama `get`.

- [ ] **Step 2: Correr e ver falhar** — `swift test --filter SprintMetricsClientTests`.

- [ ] **Step 3: Implementar** as quatro funções e o `enum SprintMetricsRequests`, todas através de `get(_:authorization:)`. `fetchSprintSnapshot` pagina `search/jql` com `nextPageToken` até acabar (50 por página); para cada chave em `truncated`, pagina `GET rest/api/3/issue/{key}/changelog?startAt=` (`isLast`) e junta com `mergeChangelogPages`, voltando a gerar os eventos com `ChangelogParser.events(fromHistories:pointsFieldName:)`. Preenche `statusCategories` com `fetchStatusCategories` e `fetchedAt = Date()`.

- [ ] **Step 4: Correr e ver passar** — `swift test --filter SprintMetricsClientTests`, depois `swift test` (tudo).

- [ ] **Step 5: Commit** — `feat(management): read sprints, issues and changelog from Jira (GET only)`.

---

### Task 4: Interface da cache e `ManagementStore`

**Files:**
- Modify: `Sources/DrIslandCore/SprintMetrics.swift`
- Create: `Sources/DrIsland/ManagementStore.swift`
- Test: `Tests/DrIslandCoreTests/SprintMetricsCacheTests.swift`

**Interfaces:**
- Consumes: tipos das Tasks 1 e 3; `Settings.jiraConfig(token:)`, `Settings.jiraSprintBoards`, `JiraClient.fetchBoards`, `JiraClient.sprintFieldID`.
- Produces:
  - `public protocol SprintMetricsCache: Sendable { func load(sprintID: Int) -> SprintSnapshot?; func save(_ snapshot: SprintSnapshot) }`
  - `public struct NoSprintMetricsCache: SprintMetricsCache` (nunca guarda; `load` devolve `nil`)
  - `@MainActor @Observable final class ManagementStore` com: `boards: [JiraBoard]`, `selectedBoard: Int?`, `sprints: [SprintRecord]`, `selectedSprint: Int?`, `unit: MetricUnit`, `snapshot: SprintSnapshot?`, `status: Status` (`.idle, .loading, .ok, .error(String)`), `burndown: BurndownResult?` (calculado de `snapshot`/`unit`), `func start()`, `func select(board:)`, `func select(sprint:)`.

- [ ] **Step 1: Escrever o teste que falha** — `noCacheNeverStores`: `NoSprintMetricsCache().save(x)` seguido de `load(sprintID:)` devolve `nil`. (O store é UI e não tem teste automático; o cálculo que ele chama já está testado.)

- [ ] **Step 2: Correr e ver falhar** — `swift test --filter SprintMetricsCacheTests`.

- [ ] **Step 3: Implementar** o protocolo e `NoSprintMetricsCache` no Core, e o `ManagementStore`: `start()` lê o token (como `JiraStore.token()`, fora da thread principal), carrega os boards (`Settings.jiraSprintBoards` filtra a lista; vazio = todos), escolhe o primeiro board e a sprint ativa (ou a mais recente); `select(sprint:)` tenta `cache.load`, e em seguida lê do Jira e faz `cache.save`. Erros do Jira vão para `ErrorLog.record("Jira", …)` e para `status = .error(texto em português)`, mantendo o último `snapshot`.

- [ ] **Step 4: Correr e ver passar** — `swift test` (tudo) e `scripts/bundle.sh release` (compila a app).

- [ ] **Step 5: Commit** — `feat(management): cache interface and management store`.

---

### Task 5: Janela «Gestão» com o gráfico

**Files:**
- Create: `Sources/DrIsland/ManagementView.swift`
- Modify: `Sources/DrIsland/AppDelegate.swift`, `Sources/DrIsland/IslandView.swift`, `Sources/DrIsland/CardTitle.swift`, `Sources/DrIsland/Settings.swift` (nome da notificação), `docs/funcionalidades.md`

**Interfaces:**
- Consumes: `ManagementStore` (Task 4), `BurndownResult` (Task 2).
- Produces: `struct ManagementView: View` (`init(store: ManagementStore)`); `Notification.Name.openManagement`; item de menu «Gestão…».

- [ ] **Step 1: Verificar que o Charts compila com o SDK fixo** — acrescentar `import Charts` e um `Chart {}` mínimo em `ManagementView.swift` e correr `scripts/bundle.sh release`. Esperado: `Built DrIsland.app`. Se falhar (SDK sem Charts), parar e avisar antes de continuar: a alternativa é desenhar com `Canvas`, como `HourlyLineChart.swift`.

- [ ] **Step 2: Implementar `ManagementView`:** seletores de stream (board), sprint e unidade (pontos/tasks); `Chart` com `LineMark` do `remaining` (cor da marca), `LineMark` tracejado do `ideal`, `AreaMark` ou linha do `scope`, e `RuleMark` no dia de hoje; linha de resumo com `doneShare` em %, `flaggedOpen`, `daysLeft` («acaba em N dias» ou «fora de prazo» se `isOverdue`); aviso «N de M tasks sem pontos» quando `showsMissingPointsWarning` com `.points`, com um botão para mudar para tasks; estados «A carregar…», erro e «Sem tasks nesta sprint». Texto em português.

- [ ] **Step 3: Abrir a janela** — em `AppDelegate`: `managementWindow` criada à maneira de `openSettings` (título «Gestão», 900×620), `@objc openManagement`, item «Gestão…» no menu da barra antes de «Definições…», e um observador de `.openManagement`. Em `CardTitle` um parâmetro opcional `onManagement: (() -> Void)?` com um botão pequeno (SF Symbol `chart.xyaxis.line`, tooltip «Gestão») que, no card da sprint em `IslandView`, publica `.openManagement`.

- [ ] **Step 4: Verificar à mão** — `scripts/bundle.sh release`, `open DrIsland.app`; abrir «Gestão…» e confirmar: o board e a sprint certos aparecem (para a Clínica, a «SPRINT #18_Clínica»), o burndown desenha-se, o seletor pontos/tasks muda o gráfico, e uma sprint fechada também abre. Confirmar em `errors.log` (menu «Registo de erros…») que não há erros do Jira, e apontar o tempo da primeira leitura (alimenta a decisão da Fase 2 sobre a cache e a barra de progresso).

- [ ] **Step 5: Documentar** — acrescentar a secção «Gestão» a `docs/funcionalidades.md` (o que mostra, seletores, só leitura, sem cache em disco nesta fase) e a linha «Gestão» na lista de menu.

- [ ] **Step 6: Correr tudo e fazer commit** — `swift test` e `scripts/bundle.sh release`; `feat(management): management window with the sprint burndown`.

---

## Self-Review

- **Cobertura da spec (Fase 1):** modelo, parser, leitor, cálculo, cache como interface, janela e gráfico 1, só leitura, seletor pontos/tasks e aviso de pontos em falta, resumo, caso «fora de prazo», botão no card da sprint → Tasks 1–5. Gráficos 2–4, cache em disco e exportação ficam, por decisão, em planos seguintes.
- **Consistência de tipos:** `SprintRecord`, `SprintIssue`, `SprintIssueEvent`, `SprintSnapshot`, `MetricUnit`, `BurndownResult` e `Burndown.compute` têm as mesmas assinaturas em todas as tarefas; `ChangelogParser.events(fromHistories:pointsFieldName:)` é definida na Task 1 e usada na Task 3.
- **A validar na execução:** que `expand=changelog` em `search/jql` devolve histórico completo neste Jira, o nome exato do campo de pontos, e que `import Charts` compila com o SDK fixo (Task 5, passo 1).
