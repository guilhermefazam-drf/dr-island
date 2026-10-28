import AppKit

@_silgen_name("CGSMainConnectionID") private func CGSMainConnectionID() -> Int32
@_silgen_name("CGSCopyManagedDisplaySpaces") private func CGSCopyManagedDisplaySpaces(_ connection: Int32) -> CFArray?

/// Whether an app is in native full screen on a display: the display's current Space is then a full-screen Space
/// (type 4). The menu bar and window bounds cannot tell, since a full-screen window sits where a maximized one does
/// on a notched Mac. This reads the window server's Space list through two long-stable CoreGraphics functions that
/// are not in the public headers; if they ever stop answering, nothing is hidden.
enum FullscreenDetector {
    private static let fullscreenSpaceType = 4

    static func isFullscreen(displayID: CGDirectDisplayID) -> Bool {
        guard let uuidRef = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue(),
              let uuid = CFUUIDCreateString(nil, uuidRef) as String?,
              let displays = CGSCopyManagedDisplaySpaces(CGSMainConnectionID()) as? [[String: Any]] else { return false }
        let display = displays.first { ($0["Display Identifier"] as? String)?.caseInsensitiveCompare(uuid) == .orderedSame }
        return (display?["Current Space"] as? [String: Any])?["type"] as? Int == fullscreenSpaceType
    }
}
