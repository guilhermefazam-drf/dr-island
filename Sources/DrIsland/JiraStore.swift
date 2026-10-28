import Foundation
import DrIslandCore

@MainActor
final class JiraStore: ObservableObject {
    enum Status: Equatable {
        case disabled, notConfigured, loading, ok, unauthorized, invalidSite, offline, rateLimited, error(Int)
    }

    @Published private(set) var tasks: [JiraTask] = []
    /// Tasks where the user is approver. `approvalsFailed` = the approver JQL was rejected or the call failed.
    @Published private(set) var approvals: [JiraTask] = []
    /// The user's own Jira display name, to tell their tasks from the others' in the approvals block.
    @Published private(set) var myName: String?
    @Published private(set) var approvalsFailed = false
    @Published private(set) var status: Status = .loading

    private let client = JiraClient()
    private var loop: Task<Void, Never>?
    private var failures = 0
    /// True while a real fetch runs (not while the source is disabled), for the sync icon.
    @Published private(set) var isRefreshing = false
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

    private func refresh() async -> TimeInterval {
        guard Settings.jiraEnabled else {
            status = .disabled
            tasks = []
            approvals = []
            return 5
        }
        let interval = Settings.jiraRefreshSeconds
        let config = Settings.jiraConfig(token: await token())
        guard config.isComplete else {
            status = .notConfigured
            tasks = []
            approvals = []
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
