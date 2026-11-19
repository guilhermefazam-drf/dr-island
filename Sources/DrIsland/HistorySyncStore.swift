import AppKit
import Observation
import DrIslandCore

/// Backs up the alert history to the user's GitHub gist or OneDrive, and brings in what other Macs recorded.
/// The history always stays in UserDefaults too: a failed sync only means there is no fresh backup.
@MainActor
@Observable
final class HistorySyncStore {
    enum Status: Equatable {
        case idle, syncing, off
        case ok(Date)
        case failed(String)
    }

    private(set) var status: Status = .idle
    /// The gist page or the OneDrive folder, for the "Abrir" button.
    private(set) var location: URL?

    private static let interval: TimeInterval = 15 * 60
    private static let debounce: Duration = .seconds(5)

    private var loop: Task<Void, Never>?
    private var pending: Task<Void, Never>?
    private var running = false
    private var again = false
    private var observers: [NSObjectProtocol] = []

    func start() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .alertHistoryChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleSync() }
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
