import Foundation
import DrIslandCore

/// Runs the focus timer: persists it, ends phases on time (even if the island is closed) and raises the alert.
@MainActor
final class FocusStore: ObservableObject {
    @Published private(set) var timer: FocusTimer
    /// Called when a phase ends, to share the island's alert channels.
    private var waiter: Task<Void, Never>?

    init() {
        timer = UserDefaults.standard.string(forKey: SettingsKey.focusState)
            .flatMap { $0.data(using: .utf8) }.flatMap { try? JSONDecoder().decode(FocusTimer.self, from: $0) } ?? FocusTimer()
    }

    var config: FocusTimer.Config { Settings.focusConfig }

    /// Picks up a timer that kept running while the app was closed.
    func start() { settle(); schedule() }

    func toggle() {
        if timer.isRunning { timer.pause(now: Date(), config) } else { timer.start(now: Date(), config) }
        changed()
    }

    func skip() { timer.skip(now: Date(), config); changed() }
    func reset() { timer.reset(); changed() }

    private func changed() { save(); schedule() }

    private func save() {
        if let data = try? JSONEncoder().encode(timer), let text = String(data: data, encoding: .utf8) {
            UserDefaults.standard.set(text, forKey: SettingsKey.focusState)
        }
    }

    /// Ends the phase if its time is up.
    private func settle() {
        guard timer.tick(now: Date(), config) != nil else { return }
        save()
    }

    /// Sleeps until the phase ends, then ends it and schedules the next one when it starts by itself.
    private func schedule() {
        waiter?.cancel()
        guard let endsAt = timer.endsAt else { return }
        waiter = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(0, endsAt.timeIntervalSinceNow) + 0.2))
            guard !Task.isCancelled, let self else { return }
            self.settle()
            self.schedule()
        }
    }
}
