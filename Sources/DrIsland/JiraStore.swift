import Foundation
import Observation
import DrIslandCore

@MainActor
@Observable
final class JiraStore {
    enum Status: Equatable {
        case disabled, notConfigured, loading, ok, unauthorized, invalidSite, offline, rateLimited, error(Int)
    }

    private(set) var tasks: [JiraTask] = []
    /// Tasks where the user is approver. `approvalsFailed` = the approver JQL was rejected or the call failed.
    private(set) var approvals: [JiraTask] = []
    /// The user's own Jira display name, to tell their tasks from the others' in the approvals block.
    private(set) var myName: String?
    private(set) var approvalsFailed = false
    /// The active sprint (nil when there is none or the "Sprint" block is off). Read apart from the tasks, so a failure keeps the last one.
    private(set) var sprint: SprintInfo?
    private var sprintField: String?
    /// Whether each Jira key found in the PR titles is in the active sprint (see `watchPRKeys`); missing = not known yet.
    private(set) var prSprint: [String: Bool] = [:]
    private var prKeys: Set<String> = []
    private(set) var status: Status = .loading

    private let client = JiraClient()
    private var loop: Task<Void, Never>?
    private var failures = 0
    /// True while a real fetch runs (not while the source is disabled), for the sync icon.
    private(set) var isRefreshing = false
    private var inFlight = false
    private var cachedToken: String?
    /// Called with Jira changes (new task, status, comments) after a successful reading.
    var onAlert: (([PRChange]) -> Void)?
    private static let baselineKey = "jiraBaseline"
    private static let approvalsBaselineKey = "jiraApprovalsBaseline"
    private var approvalsBaseline: [JiraFingerprint]? = UserDefaults.standard.data(forKey: JiraStore.approvalsBaselineKey)
        .flatMap { try? JSONDecoder().decode([JiraFingerprint].self, from: $0) }
    private var baseline: [JiraFingerprint]? = UserDefaults.standard.data(forKey: JiraStore.baselineKey)
        .flatMap { try? JSONDecoder().decode([JiraFingerprint].self, from: $0) }
    private var observer: NSObjectProtocol?

    init() {
        observer = NotificationCenter.default.addObserver(forName: .jiraTokenChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.cachedToken = nil
                self?.refreshNow()
            }
        }
    }

    func start() {
        loop?.cancel()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.inFlight = true
                let delay = await self.refresh()
                self.inFlight = false
                try? await Task.sleep(for: .seconds(delay))
            }
        }
    }

    /// Ignored while a fetch is running: cancelling it midway would leave two fetches racing on the same state.
    func refreshNow() { guard !inFlight else { return }; start() }

    /// Reads the Keychain once and keeps the token in memory, so a locked or prompting Keychain is not hit every cycle.
    /// The read runs off the main thread: a slow or prompting Keychain froze the whole island for seconds.
    private func token() async -> String {
        if let cachedToken { return cachedToken }
        let account = Settings.jiraTokenAccount
        let value = await Task.detached(priority: .userInitiated) { SecretStore.read(account: account) ?? "" }.value
        if !value.isEmpty { cachedToken = value }
        return value
    }

    /// Independent of the main reading: a bad approver JQL must not hide the user's own tasks.
    private func refreshApprovals(_ config: JiraConfig) async {
        guard Settings.jiraApproverEnabled else {
            approvals = []
            approvalsFailed = false
            return
        }
        do {
            let fresh = try await client.fetchApprovals(config)
            // Same diff as the user's own tasks; a task already announced there is not announced twice.
            let own = Set(tasks.map(\.key))
            let changes = JiraDiff.changes(from: approvalsBaseline, to: fresh, me: myName).filter { !own.contains($0.ref) }
            approvalsBaseline = JiraDiff.fingerprints(of: fresh, me: myName)
            if let data = try? JSONEncoder().encode(approvalsBaseline) { UserDefaults.standard.set(data, forKey: Self.approvalsBaselineKey) }
            if !changes.isEmpty { onAlert?(changes) }
            approvals = fresh
            approvalsFailed = false
        } catch {
            approvalsFailed = true   // keep the last good list
            ErrorLog.record("Jira", "Aprovações: \(error)")
        }
    }

    /// The Jira keys the PR lists mention. Looked up when they change, and again on every Jira reading.
    func watchPRKeys(_ keys: Set<String>) {
        guard keys != prKeys else { return }
        prKeys = keys
        Task { [weak self] in
            guard let self else { return }
            await self.refreshPRSprint(Settings.jiraConfig(token: await self.token()))
        }
    }

    private func refreshPRSprint(_ config: JiraConfig) async {
        guard Settings.showSprint, sprint != nil, let field = sprintField, config.isComplete, !prKeys.isEmpty else {
            if !prSprint.isEmpty { prSprint = [:] }
            return
        }
        do { prSprint = try await client.fetchSprintMembership(config, keys: Array(prKeys), field: field) }
        catch { ErrorLog.record("Jira", "PRs da sprint: \(error)") }   // keep the last answer
    }

    private func refreshSprint(_ config: JiraConfig) async {
        guard Settings.showSprint else { sprint = nil; return }
        do {
            let result = try await client.fetchActiveSprint(config, field: sprintField)
            sprintField = result.field
            sprint = result.sprint
        } catch {
            ErrorLog.record("Jira", "Sprint: \(error)")   // keep the last sprint
        }
    }

    private func refresh() async -> TimeInterval {
        guard Settings.jiraEnabled else {
            status = .disabled
            tasks = []
            approvals = []
            sprint = nil
            return 5
        }
        let interval = Settings.jiraRefreshSeconds
        let config = Settings.jiraConfig(token: await token())
        guard config.isComplete else {
            status = .notConfigured
            tasks = []
            approvals = []
            sprint = nil
            return 10
        }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            if myName == nil { myName = try? await client.myself(config) }
            // With the sprint shown, each task also says whether it is in the active sprint ("Fora da Sprint").
            if Settings.showSprint, sprintField == nil { sprintField = try? await client.sprintFieldID(config) }
            let fresh = try await client.fetchTasks(config, sprintField: Settings.showSprint ? sprintField : nil)
            // Only a successful reading is compared, as with PRs.
            let changes = JiraDiff.changes(from: baseline, to: fresh, me: myName)
            baseline = JiraDiff.fingerprints(of: fresh, me: myName)
            if let data = try? JSONEncoder().encode(baseline) { UserDefaults.standard.set(data, forKey: Self.baselineKey) }
            if !changes.isEmpty { onAlert?(changes) }
            tasks = fresh
            await refreshApprovals(config)
            await refreshSprint(config)
            await refreshPRSprint(config)
            status = .ok
            failures = 0
            return interval
        } catch {
            failures += 1
            ErrorLog.record("Jira", error: error)
            switch error as? JiraError {
            case .unauthorized: status = .unauthorized; cachedToken = nil
            case .invalidSite: status = .invalidSite
            case .rateLimited: status = .rateLimited
            case .http(let code): status = .error(code)
            case .notConfigured: status = .notConfigured
            default: status = .offline
            }
            // Keep the last good tasks visible; back off on repeated failures.
            return min(interval * pow(2, Double(min(failures - 1, 3))), 900)
        }
    }
}
