import AppKit
import UserNotifications
import DrIslandCore

/// The alert channels that live outside the island window: sound and macOS notifications.
/// (Pulse, dot, row highlight and the peek are drawn by the island itself.)
@MainActor
enum PRAlerts {
    static func dispatch(_ changes: [PRChange]) {
        guard let loudest = changes.max(by: { $0.tone < $1.tone }), !Settings.isQuiet else { return }
        if Settings.alertSound {
            let name: NSSound.Name = loudest.tone == .critical ? "Basso" : (loudest.tone == .success ? "Glass" : "Tink")
            NSSound(named: name)?.play()
        }
        if Settings.alertNotification, canNotify { notify(changes) }
    }

    /// `UNUserNotificationCenter` needs a real app bundle; a bare binary would crash.
    private static var canNotify: Bool { Bundle.main.bundleIdentifier != nil && Bundle.main.bundlePath.hasSuffix(".app") }

    static func requestNotificationPermission() {
        guard canNotify else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private static func notify(_ changes: [PRChange]) {
        let content = UNMutableNotificationContent()
        content.title = changes.count == 1 ? "Dr Island" : "Dr Island · \(changes.count) alterações"
        content.body = changes.prefix(3).map(\.message).joined(separator: "\n")
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
