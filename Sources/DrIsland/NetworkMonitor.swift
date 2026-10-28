import Foundation
import Network

/// Tracks whether the Mac has a usable network path. The usage, PR and Jira numbers all come from the internet,
/// so the island turns its border red while offline and refreshes everything as soon as the connection is back.
@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published private(set) var isOnline = true
    /// Called once each time the connection comes back after having been lost.
    var onReconnect: (() -> Void)?
    /// Called as soon as the connection is lost (not for the initial state).
    var onDisconnect: (() -> Void)?

    private let monitor = NWPathMonitor()

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in self?.update(online: online) }
        }
        monitor.start(queue: DispatchQueue(label: "DrIsland.NetworkMonitor"))
    }

    private func update(online: Bool) {
        guard online != isOnline else { return }
        isOnline = online
        guard online else { onDisconnect?(); return }
        // DNS and routes are often not ready the instant the path turns satisfied; a short wait avoids a failed first try.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            MainActor.assumeIsolated { if self?.isOnline == true { self?.onReconnect?() } }
        }
    }
}
