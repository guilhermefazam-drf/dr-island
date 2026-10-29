import AppKit
import SwiftUI
import DrIslandCore

/// Transparent, click-through panel pinned to the top centre of the target screen.
/// It always has the expanded size so the SwiftUI spring animation needs no window resizing;
/// mouse events pass through to the apps below except while the island is expanded.
final class IslandPanel: NSPanel {
    init(frame: CGRect) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isFloatingPanel = true
        level = .statusBar   // after isFloatingPanel, which resets the level to .floating
        hidesOnDeactivate = false
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    }

    /// The frame the controller wants; AppKit/SwiftUI must never change it (the island animates inside it).
    var lockedFrame: CGRect?

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        super.setFrame(lockedFrame ?? frameRect, display: flag)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    // The notch lives inside the menu bar area, which AppKit would otherwise push windows out of.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}
