import AppKit
import DrIslandCore

@MainActor
enum ShortcutLauncher {
    /// Opens the app, on the pinned folder when there is one; an app already running is brought to the front.
    static func open(_ shortcut: DevShortcut) {
        let appURL = URL(fileURLWithPath: shortcut.appPath)
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        if let folder = shortcut.folder, FileManager.default.fileExists(atPath: folder) {
            NSWorkspace.shared.open([URL(fileURLWithPath: folder)], withApplicationAt: appURL, configuration: configuration)
        } else {
            NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
        }
    }
}
