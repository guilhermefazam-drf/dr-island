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
    private(set) var sprints: [SprintInfo] = []
    /// The active sprint's tasks that are or were the user's, so a task keeps showing after it changes owner.
    private(set) var sprintTasks: [JiraTask] = []
    private var sprintField: String?
    /// The team backlog grouped by future sprint ("Backlog" block). `backlogTruncated` = more tasks than were read;
    /// `backlogFailed` = the last reading failed (the last good groups stay).
    private(set) var backlog: [BacklogGroup] = []
    private(set) var backlogTruncated = false
    private(set) var backlogFailed = false
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
            if Settings.showSprint, sprintField == nil { sprintField = try? await client.sprintFieldID(config) }
            let fresh = try await client.fetchApprovals(config, sprintField: Settings.showSprint ? sprintField : nil)
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

    /// Independent of the main reading, as the approvals. Needs the Sprint field to split by sprint; without it all is "Backlog".
    private func refreshBacklog(_ config: JiraConfig) async {
        if Settings.jiraBacklogEnabled, sprintField == nil { sprintField = try? await client.sprintFieldID(config) }
        guard Settings.jiraBacklogEnabled,
              let jql = Settings.jiraBacklogJQL(guessedProject: Backlog.guessProject(from: tasks.map(\.key)), sprintField: sprintField) else {
            backlog = []
            backlogFailed = false
            return
        }
        do {
            let result = try await client.fetchBacklog(config, jql: jql, sprintField: sprintField)
            backlog = result.groups
            backlogTruncated = result.truncated
            backlogFailed = false
        } catch {
            backlogFailed = true
            ErrorLog.record("Jira", "Backlog: \(error)")
        }
    }

    private func refreshSprintTasks(_ config: JiraConfig) async {
        guard Settings.showSprint else { sprintTasks = []; return }
        do { sprintTasks = try await client.fetchSprintTasks(config, field: sprintField, sprintIDs: sprints.compactMap(\.id)) }
        catch { ErrorLog.record("Jira", "Tasks da sprint: \(error)") }   // keep the last list
    }

    private func refreshSprint(_ config: JiraConfig) async {
        guard Settings.showSprint else { sprints = []; return }
        do {
            let result = try await client.fetchActiveSprints(config, field: sprintField, boards: Settings.jiraSprintBoards)
            sprintField = result.field
            sprints = result.sprints
        } catch {
            ErrorLog.record("Jira", "Sprint: \(error)")   // keep the last sprints
        }
    }

    private func refresh() async -> TimeInterval {
        guard Settings.jiraEnabled else {
            status = .disabled
            tasks = []
            approvals = []
            sprints = []
            sprintTasks = []
            backlog = []
            return 5
        }
        let interval = Settings.jiraRefreshSeconds
        let config = Settings.jiraConfig(token: await token())
        guard config.isComplete else {
            status = .notConfigured
            tasks = []
            approvals = []
            sprints = []
            sprintTasks = []
            backlog = []
            return 10
        }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            if myName == nil { myName = try? await client.myself(config) }
            let fresh = try await client.fetchTasks(config)
            // Only a successful reading is compared, as with PRs.
            let changes = JiraDiff.changes(from: baseline, to: fresh, me: myName)
            baseline = JiraDiff.fingerprints(of: fresh, me: myName)
            if let data = try? JSONEncoder().encode(baseline) { UserDefaults.standard.set(data, forKey: Self.baselineKey) }
            if !changes.isEmpty { onAlert?(changes) }
            tasks = fresh
            await refreshApprovals(config)
            await refreshSprint(config)
            await refreshSprintTasks(config)
            await refreshBacklog(config)
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
