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

/// App icons at full resolution. `NSWorkspace.icon(forFile:)` reports a 32 pt image, so on a 1x external
/// monitor SwiftUI picks the 32 px representation and the Dock-style magnification blows it up blurry.
/// Declaring a large size makes it pick the biggest representation and scale it down smoothly instead.
@MainActor
enum AppIcons {
    private static var cache: [String: NSImage] = [:]

    static func icon(forFile path: String) -> NSImage {
        if let cached = cache[path] { return cached }
        let image = (NSWorkspace.shared.icon(forFile: path).copy() as? NSImage) ?? NSWorkspace.shared.icon(forFile: path)
        image.size = NSSize(width: 256, height: 256)
        cache[path] = image
        return image
    }
}
