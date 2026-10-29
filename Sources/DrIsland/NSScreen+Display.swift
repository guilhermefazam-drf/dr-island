import AppKit
import SwiftUI
import DrIslandCore

extension NSScreen {
    /// Survives reboots and re-plugging, unlike the numeric display id.
    var stableID: String {
        guard let id = displayID, let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue(),
              let str = CFUUIDCreateString(nil, uuid) as String? else { return localizedName }
        return str
    }

    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber).map { CGDirectDisplayID($0.uint32Value) }
    }
}
