import SwiftUI

extension View {
    /// The pointing-hand cursor over clickable things. `pointerStyle` (macOS 15) is the reliable way; on macOS 14 it falls
    /// back to setting the cursor on hover, which the system may reset on the next mouse move.
    func pointingHandCursor() -> some View { modifier(PointingHandCursor()) }
}

private struct PointingHandCursor: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15, *) {
            content.pointerStyle(.link)
        } else {
            content.onHover { inside in (inside ? NSCursor.pointingHand : NSCursor.arrow).set() }
        }
    }
}
