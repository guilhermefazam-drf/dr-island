import AppKit
import ApplicationServices

/// The keyboard's play/pause, next and previous keys, sent to whatever the system is playing (a browser tab, a podcast app…).
/// The system's own "send command" API silently ignores third-party apps, so this is how a browser is controlled.
/// Posting key events needs the Accessibility permission, which the app asks for the first time it is needed.
enum MediaKey {
    case playPause, next, previous

    fileprivate var code: Int32 {
        switch self {
        case .playPause: return 16   // NX_KEYTYPE_PLAY
        case .next: return 17        // NX_KEYTYPE_NEXT
        case .previous: return 18    // NX_KEYTYPE_PREVIOUS
        }
    }
}

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
