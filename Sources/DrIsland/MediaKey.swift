import AppKit
import ApplicationServices

/// The keyboard's play/pause, next and previous keys, sent to whatever the system is playing (a browser tab, a podcast app…).
/// The system's own "send command" API silently ignores third-party apps, so this is how a browser is controlled.
/// Posting key events needs the Accessibility permission, which the app asks for the first time it is needed.
enum MediaKey {
    case playPause, next, previous

    var code: Int32 {
        switch self {
        case .playPause: return 16   // NX_KEYTYPE_PLAY
        case .next: return 17        // NX_KEYTYPE_NEXT
        case .previous: return 18    // NX_KEYTYPE_PREVIOUS
        }
    }
}
