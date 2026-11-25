import AppKit
import Observation
import DrIslandCore

/// Backs up the alert history to the user's GitHub gist or OneDrive, and brings in what other Macs recorded.
/// The history always stays in UserDefaults too: a failed sync only means there is no fresh backup.
/// With the gist, the preferences go to the same gist too (see `SyncedSettings`, `SettingsSync`).
@MainActor
@Observable
final class HistorySyncStore {
    enum Status: Equatable {
        case idle, syncing, off
        case ok(Date)
        case failed(String)
    }

    private(set) var status: Status = .idle
    /// The preferences' backup (gist only); `.off` when it is switched off or the history is not on the gist.
    private(set) var settingsStatus: Status = .idle
    /// The gist page or the OneDrive folder, for the "Abrir" button.
    private(set) var location: URL?

    private static let interval: TimeInterval = 15 * 60
    private static let debounce: Duration = .seconds(5)

    private var loop: Task<Void, Never>?
    private var pending: Task<Void, Never>?
    private var running = false
    private var again = false
    private var observers: [NSObjectProtocol] = []
    /// The synced preferences as last seen, to tell a change made here from any other UserDefaults write.
    private var lastSettings: [String: SettingValue] = [:]
    private var settingsCheck: Task<Void, Never>?

    func start() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .alertHistoryChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleSync() }
        })
        lastSettings = SyncedSettings.values()
        observers.append(center.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleSettingsCheck() }
        })
        loop = Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))   // let the first readings settle
            while !Task.isCancelled {
                await self?.sync()
                try? await Task.sleep(for: .seconds(Self.interval))
            }
        }
    }

    func syncNow() { Task { await sync() } }

    /// UserDefaults changes all the time (readings, baselines); after a short pause, see whether a synced preference
    /// changed here and, if so, stamp it and back it up.
    private func scheduleSettingsCheck() {
        settingsCheck?.cancel()
        settingsCheck = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, let self else { return }
            let now = SyncedSettings.values()
            guard now != self.lastSettings else { return }
            self.lastSettings = now
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: SettingsKey.settingsChangedAt)
            if Settings.settingsSyncEnabled && Settings.historySyncMode == .gist { self.scheduleSync() }
        }
    }

    /// Several alerts at once become one write.
    private func scheduleSync() {
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(for: Self.debounce)
            guard !Task.isCancelled else { return }
            await self?.sync()
        }
    }

    private func sync() async {
        if running { again = true; return }
        running = true
        defer {
            running = false
            if again { again = false; syncNow() }
        }
        let mode = Settings.historySyncMode
        if mode != .gist || !Settings.settingsSyncEnabled { settingsStatus = .off }
        guard mode != .local else { status = .off; location = nil; return }
        status = .syncing
        let local = Settings.historyBackup
        do {
            let plan: HistorySync.Plan
            switch mode {
            case .gist:
                let defaults = UserDefaults.standard
                guard let client = GistSyncClient(ghPath: defaults.string(forKey: SettingsKey.githubGhPath)) else { throw GitHubError.notInstalled }
                let knownID = defaults.string(forKey: SettingsKey.historyGistID)
                let knownLogin = defaults.string(forKey: SettingsKey.historyGistLogin)
                let result = try await Task.detached { try client.sync(local, knownID: knownID, knownLogin: knownLogin) }.value
                defaults.set(result.gistID, forKey: SettingsKey.historyGistID)
                defaults.set(result.login, forKey: SettingsKey.historyGistLogin)
                location = GistSyncClient.url(id: result.gistID)
                plan = result.plan
                if Settings.settingsSyncEnabled { await syncSettings(client: client, gistID: result.gistID) }
            case .oneDrive:
                guard let root = OneDriveBackup.roots().first else { throw HistorySyncFailure.noOneDrive }
                let folder = OneDriveBackup.folder(root: root)
                location = folder
                plan = try await Task.detached {
                    try OneDriveBackup.sync(local, folder: folder, device: Host.current().localizedName ?? "mac")
                }.value
            case .local:
                return
            }
            // Mode changed while this sync ran: what it read belongs to the old destination.
            guard Settings.historySyncMode == mode else { return }
            if plan.updateLocal {
                // Merged again with what arrived meanwhile, so an alert recorded during the sync is not lost.
                Settings.historyBackup = HistorySync.merge(Settings.historyBackup, plan.merged)
            }
            status = .ok(Date())
        } catch {
            let message = Self.describe(error)
            if status != .failed(message) { ErrorLog.record("Histórico", "Sincronização (\(mode.title)): \(error)") }
            status = .failed(message)
        }
    }

    /// The preferences, in the same gist as the history: the newest change wins, a Mac that never synced adopts the
    /// gist's. A failure here is reported on its own and never fails the history's sync.
    private func syncSettings(client: GistSyncClient, gistID: String) async {
        settingsStatus = .syncing
        let defaults = UserDefaults.standard
        let local = SyncedSettings.backup()
        let firstSync = !defaults.bool(forKey: SettingsKey.settingsSyncedOnce)
        do {
            let remote = try await Task.detached { try client.readSettings(id: gistID) }.value
            switch SettingsSync.plan(local: local, remote: remote, firstSync: firstSync, allowed: SyncedSettings.keys) {
            case .none:
                break
            case .upload:
                try await Task.detached { try client.updateSettings(id: gistID, local) }.value
            case .apply(let values):
                SyncedSettings.apply(values)
                // What came from the gist is not a change made here: keep its date and do not send it back.
                lastSettings = SyncedSettings.values()
                defaults.set(remote?.updatedAt.timeIntervalSince1970 ?? 0, forKey: SettingsKey.settingsChangedAt)
            }
            defaults.set(true, forKey: SettingsKey.settingsSyncedOnce)
            settingsStatus = .ok(Date())
        } catch {
            let message = Self.describe(error)
            if settingsStatus != .failed(message) { ErrorLog.record("Definições", "Sincronização (gist): \(error)") }
            settingsStatus = .failed(message)
        }
    }

    private enum HistorySyncFailure: Error { case noOneDrive }

    static func describe(_ error: Error) -> String {
        switch error {
        case GitHubError.notInstalled: return "gh não encontrado. Indica o caminho em Definições → GitHub."
        case GitHubError.notAuthenticated: return "O gh não tem sessão iniciada: corre «gh auth login» no Terminal."
        case GistSyncError.notFound: return "Sem acesso aos gists: corre «gh auth refresh -s gist» no Terminal."
        case GistSyncError.truncated: return "O gist ficou demasiado grande para ser lido."
        case GistSyncError.invalidResponse: return "O gist não tem um histórico válido."
        case GitHubError.failed(let line): return line
        case HistorySyncFailure.noOneDrive: return "Pasta do OneDrive não encontrada. Instala a app do OneDrive e inicia sessão."
        default: return error.localizedDescription
        }
    }
}
