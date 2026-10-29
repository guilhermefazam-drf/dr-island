import AppKit
import ApplicationServices

enum MediaKeys {
    static var isAllowed: Bool { AXIsProcessTrusted() }

    /// Shows the system's "allow in Accessibility" prompt. macOS shows that prompt only once (and never again after a denial or a
    /// rebuild), so when it has no effect the Accessibility pane of System Settings is opened instead.
    static func requestAccess() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        openSettings(pane: "Privacy_Accessibility")
    }

    /// Opens a Privacy & Security pane of System Settings (e.g. `Privacy_Accessibility`, `Privacy_Automation`).
    static func openSettings(pane: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") else { return }
        NSWorkspace.shared.open(url)
    }

    static func send(_ key: MediaKey) {
        for down in [true, false] {
            let state: Int32 = down ? 0xa : 0xb
            let event = NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(state << 8)),
                                           timestamp: 0, windowNumber: 0, context: nil, subtype: 8,
                                           data1: Int((key.code << 16) | (state << 8)), data2: -1)
            event?.cgEvent?.post(tap: .cghidEventTap)
        }
    }
}
