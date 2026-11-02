import Foundation
import Observation
import DrIslandCore

/// State of the «Gestão» window: boards, sprints and the burndown of the selected sprint. Jira is read-only.
@MainActor
@Observable
final class ManagementStore {
    enum Status: Equatable {
        case idle, loading, ok, error(String)
    }

    private(set) var boards: [JiraBoard] = []
    private(set) var selectedBoard: Int?
    private(set) var sprints: [SprintRecord] = []
    private(set) var selectedSprint: Int?
    var unit: MetricUnit = .points
    private(set) var snapshot: SprintSnapshot?
    private(set) var status: Status = .idle
    /// The bugs and velocity charts' data.
    let side = ManagementSideData()

    /// False when the site has no story-points field: only «tasks» makes sense then.
    var hasPointsField: Bool { points != nil }

    /// The unit actually used: without a story-points field only tasks can be counted.
    var effectiveUnit: MetricUnit { hasPointsField ? unit : .tasks }

    /// Derived from `snapshot` and `unit`; the Observation framework tracks both through this computed property.
    var burndown: BurndownResult? {
        snapshot.map { Burndown.compute($0, unit: effectiveUnit, now: Date(), calendar: .current) }
    }

    @ObservationIgnored private let cache: SprintMetricsCache
    @ObservationIgnored private let client = JiraClient()
    @ObservationIgnored private var config: JiraConfig?
    @ObservationIgnored private var sprintField: String?
    private var points: (id: String, name: String)?
    /// Guards against a slower, older load overwriting a newer selection.
    @ObservationIgnored private var generation = 0

    init(cache: SprintMetricsCache = NoSprintMetricsCache()) {
        self.cache = cache
    }

    /// Called when the «Gestão» page comes into view: reads (or refreshes) unless a read is already running.
    func refreshIfNeeded() {
        if ProcessInfo.processInfo.environment["DR_ISLAND_FAKE_MANAGEMENT"] != nil { loadDemo(); return }
        if status != .loading { start() }
    }

    /// `DR_ISLAND_FAKE_MANAGEMENT`: a made-up sprint instead of Jira, to see the page.
    private func loadDemo() {
        boards = ManagementDemo.boards
        selectedBoard = 483
        sprints = ManagementDemo.sprints()
        selectedSprint = sprints.first?.id
        points = (id: "customfield_10008", name: "Story Points")
        snapshot = ManagementDemo.snapshot()
        status = .ok
        side.loadDemo()
    }

    func start() {
        generation += 1
        let mine = generation
        status = .loading
        Task { [weak self] in
            guard let self else { return }
            let account = Settings.jiraTokenAccount
            let token = await Task.detached(priority: .userInitiated) { SecretStore.read(account: account) ?? "" }.value
            guard mine == self.generation else { return }
            let config = Settings.jiraConfig(token: token)
            guard Settings.jiraEnabled, config.isComplete else {
                self.status = .error("Jira não está configurado. Ver Definições → Jira.")
                return
            }
            self.config = config
            do {
                let all = try await self.client.fetchBoards(config)
                let chosen = Settings.jiraSprintBoards
                if self.sprintField == nil { self.sprintField = try await self.client.sprintFieldID(config) }
                var boards = all
                if !chosen.isEmpty {
                    boards = all.filter { chosen.contains($0.id) }
                } else if let active = try? await self.client.fetchActiveSprints(config, field: self.sprintField, boards: []) {
                    // No boards chosen: the boards of the sprints the user had tasks in; all boards if that yields none.
                    let ids = Set(active.sprints.compactMap(\.boardID))
                    let mineBoards = all.filter { ids.contains($0.id) }
                    if !mineBoards.isEmpty { boards = mineBoards }
                }
                guard mine == self.generation else { return }
                self.boards = boards
                self.points = try await self.client.fetchPointsField(config)
                guard mine == self.generation else { return }
                // Keep the manager's selection across reopenings when it is still available.
                guard let board = boards.first(where: { $0.id == self.selectedBoard }) ?? boards.first else {
                    self.sprints = []
                    self.selectedBoard = nil
                    self.selectedSprint = nil
                    self.status = .error("Não foram encontrados quadros Jira.")
                    return
                }
                await self.loadBoard(board.id, config: config, generation: mine)
            } catch {
                guard mine == self.generation else { return }
                self.fail(error)
            }
        }
    }

    func select(board: Int) {
        guard let config else { return }
        generation += 1
        let mine = generation
        Task { [weak self] in await self?.loadBoard(board, config: config, generation: mine) }
    }

    func select(sprint: Int) {
        guard let config, let record = sprints.first(where: { $0.id == sprint }) else { return }
        generation += 1
        let mine = generation
        Task { [weak self] in await self?.loadSprint(record, config: config, generation: mine) }
    }

    private func loadBoard(_ id: Int, config: JiraConfig, generation mine: Int) async {
        guard mine == generation else { return }
        let preferred = selectedBoard == id ? selectedSprint : nil
        if selectedBoard != id {
            // Another board: its sprints are not the previous board's.
            sprints = []
            selectedSprint = nil
        }
        selectedBoard = id
        status = .loading
        do {
            let list = try await client.fetchBoardSprints(config, boardID: id)
            guard mine == generation else { return }
            sprints = list
            side.loadVelocity(config: config, sprints: list, sprintField: sprintField, points: points)
            guard let pick = list.first(where: { $0.id == preferred }) ?? list.first(where: { $0.state == "active" }) ?? list.first else {
                selectedSprint = nil
                snapshot = nil
                status = .ok
                return
            }
            await loadSprint(pick, config: config, generation: mine)
        } catch {
            guard mine == generation else { return }
            sprints = []
            selectedSprint = nil
            fail(error, readingBoard: true)
        }
    }

    private func loadSprint(_ sprint: SprintRecord, config: JiraConfig, generation mine: Int) async {
        guard mine == generation else { return }
        selectedSprint = sprint.id
        if let cached = cache.load(sprintID: sprint.id) {
            snapshot = cached
            status = .ok
            // A closed sprint no longer changes: the cached copy is final.
            if cached.sprint.state == "closed" {
                side.loadBugs(config: config, project: Backlog.guessProject(from: cached.issues.map(\.key)))
                return
            }
        }
        status = .loading
        guard let sprintField else {
            status = .error("Não foi possível identificar o campo Sprint do Jira.")
            return
        }
        do {
            let fresh = try await client.fetchSprintSnapshot(config, sprint: sprint, sprintField: sprintField, points: points)
            guard mine == generation else { return }
            snapshot = fresh
            status = .ok
            if sprint.state == "closed" { cache.save(fresh) }
            side.loadBugs(config: config, project: Backlog.guessProject(from: fresh.issues.map(\.key)))
        } catch {
            guard mine == generation else { return }
            fail(error)
        }
    }

    /// Keeps the last snapshot on screen. `readingBoard`: a 401/403 on a board call means no permission on that board
    /// (the credentials were already proven by the boards list).
    private func fail(_ error: Error, readingBoard: Bool = false) {
        ErrorLog.record("Jira", "Gestão: \(error)")
        switch error as? JiraError {
        case .unauthorized where readingBoard:
            status = .error("Sem permissão para ler este board. Escolha outro ou deixe a lista vazia em Definições → Jira (modo automático).")
        case .unauthorized: status = .error("Jira recusou as credenciais. Verifique o email e o token.")
        case .invalidSite: status = .error("O endereço do Jira é inválido.")
        case .rateLimited: status = .error("O Jira limitou os pedidos. Tente daqui a pouco.")
        case .http(let code): status = .error("O Jira respondeu com o erro \(code).")
        case .notConfigured: status = .error("Jira não está configurado. Ver Definições → Jira.")
        case .invalidResponse: status = .error("Resposta inesperada do Jira.")
        case .readOnly: status = .error("Pedido recusado: a app só lê do Jira.")
        default: status = .error("Sem ligação ao Jira.")
        }
    }
}
