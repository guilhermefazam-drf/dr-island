import AppKit
import DrIslandCore

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
