import Foundation
import DrIslandCore

@MainActor
final class PullRequestStore: ObservableObject {
    enum Status: Equatable {
        case disabled, loading, ok, notInstalled, notAuthenticated, error(String)
    }

    @Published private(set) var snapshot = PullRequestSnapshot()
    @Published private(set) var status: Status = .loading

    /// Changes the user has not seen yet; cleared when the island is closed after being opened. Persisted.
    @Published private(set) var unseen: [PRChange] = []
    /// Bumped whenever a reading brought changes, so views can play their alert.
    @Published private(set) var alertTick = 0
    private(set) var lastChanges: [PRChange] = []

    private static let baselineKey = "prBaseline"
    private static let unseenKey = "prUnseen"
    private static let versionKey = "prBaselineVersion"
    private static let maxUnseen = 40

    private let client = GitHubClient()
    /// Fingerprints of the last successful reading, kept in UserDefaults so changes made while the app was closed are noticed.
    private var baseline: [PRFingerprint]?
    private var loop: Task<Void, Never>?
    private var failures = 0
    /// True while a real fetch runs (not while the source is disabled), for the sync icon.
    @Published private(set) var isRefreshing = false
    private var inFlight = false

    init() {
        let defaults = UserDefaults.standard
        // Version 2 added comments, mentions and merged PRs: older caches lack them, so start over silently.
        if defaults.integer(forKey: Self.versionKey) < 2 {
            defaults.removeObject(forKey: Self.baselineKey)
            defaults.set(2, forKey: Self.versionKey)
        }
        baseline = defaults.data(forKey: Self.baselineKey).flatMap { try? JSONDecoder().decode([PRFingerprint].self, from: $0) }
        unseen = defaults.data(forKey: Self.unseenKey).flatMap { try? JSONDecoder().decode([PRChange].self, from: $0) } ?? []
    }

    /// Muted PRs never light the attention dot.
    var attention: PullRequest.Attention {
        let mutes = Settings.prMutes
        return status == .ok ? (snapshot.authored.filter { !PRMutes.isMuted(prID: $0.id, in: mutes) }.map(\.attention).max() ?? .none) : .none
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

    private func refresh() async -> TimeInterval {
        guard Settings.githubEnabled else {
            status = .disabled
            snapshot = PullRequestSnapshot()
            return 5
        }
        let interval = Settings.githubRefreshSeconds
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            var fresh = try await client.fetch(Settings.githubOptions)
            fresh = fresh.resolvingUnknownConflicts(using: baseline)
            // An empty list that was not empty before is usually the search index hiccuping: ask again before believing it.
            var retries = 0
            while fresh.looksTruncated(comparedTo: baseline), retries < 3 {
                retries += 1
                try? await Task.sleep(for: .seconds(2))
                fresh = try await client.fetch(Settings.githubOptions)
            }
            // Only a successful reading is compared: a failed one must never look like "every PR was closed".
            register(PullRequestDiff.changes(from: baseline, to: fresh))
            baseline = PullRequestDiff.fingerprints(of: fresh)
            saveBaseline()
            snapshot = fresh
            status = .ok
            failures = 0
            return interval
        } catch {
            failures += 1
            ErrorLog.record("GitHub", error: error)
            switch error as? GitHubError {
            case .notInstalled: status = .notInstalled
            case .notAuthenticated: status = .notAuthenticated
            case .failed(let message): status = .error(message)
            default: status = .error("Resposta inesperada do GitHub")
            }
            // Keep the last good snapshot visible; retry sooner for fixable setup problems.
            let setupProblem = status == .notInstalled || status == .notAuthenticated
            return setupProblem ? min(interval, 30) : min(interval * pow(2, Double(min(failures - 1, 3))), 900)
        }
    }

    // MARK: Changes

    func markSeen() {
        guard !unseen.isEmpty else { return }
        unseen = []
        saveUnseen()
    }

    /// Fires a sample alert (from the settings window) without touching the cache.
    /// It targets a real PR from the list, so the tag shows on its row, and cycles through the reasons to show each colour.
    func simulateAlert(kind forced: PRChange.Kind? = nil) {
        let kinds: [PRChange.Kind] = [.ciFailed, .changesRequested, .conflicts, .approved, .newComment, .reviewRequested]
        let kind = forced ?? kinds[sampleIndex % kinds.count]
        if forced == nil { sampleIndex += 1 }
        let target = snapshot.authored.first ?? snapshot.reviewRequested.first
        let sample = target.map { PRChange(prID: $0.id, ref: PRFingerprint($0).ref, title: $0.title, kind: kind) }
            ?? PRChange(prID: "sample", ref: "exemplo#1", title: "PR de exemplo", kind: kind)
        unseen = unseen.filter { $0.prID != sample.prID } + [sample]
        sampleIDs.insert(sample.id)   // saveUnseen leaves it out: a sample on a real PR must never be read back as a real alert
        announce([sample])
    }
    private var sampleIndex = 0
    private var sampleIDs: Set<String> = []

    /// Every git and Jira alert shares the dot, the peek and the other channels.
    func register(_ detected: [PRChange], record: Bool = true) {
        let mutes = Settings.prMutes
        let changes = detected.filter { Settings.allows($0.kind) && !PRMutes.isMuted(prID: $0.prID, in: mutes) }
        guard !changes.isEmpty else { return }
        let ids = Set(changes.map(\.id))
        sampleIDs.subtract(ids)   // a real alert with the same id replaces the sample
        unseen = Array((unseen.filter { !ids.contains($0.id) } + changes).suffix(Self.maxUnseen))
        saveUnseen()
        if record {
            let log = AlertLog.appending(changes, to: AlertLog.decode(UserDefaults.standard.string(forKey: SettingsKey.alertHistory)))
            UserDefaults.standard.set(AlertLog.encode(log), forKey: SettingsKey.alertHistory)
        }
        announce(changes)
    }

    /// Shows something in the mini island only: no history, no unseen dot, no sound or macOS notification.
    func showTransient(_ changes: [PRChange]) {
        lastChanges = changes
        NotificationCenter.default.post(name: .prChangesDetected, object: nil)
    }

    private func announce(_ changes: [PRChange]) {
        lastChanges = changes
        alertTick += 1
        PRAlerts.dispatch(changes)
        NotificationCenter.default.post(name: .prChangesDetected, object: nil)
    }

    private func saveBaseline() {
        if let data = try? JSONEncoder().encode(baseline) { UserDefaults.standard.set(data, forKey: Self.baselineKey) }
    }

    private func saveUnseen() {
        let real = unseen.filter { !sampleIDs.contains($0.id) }
        if let data = try? JSONEncoder().encode(real) { UserDefaults.standard.set(data, forKey: Self.unseenKey) }
    }
}
