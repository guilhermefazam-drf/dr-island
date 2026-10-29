import AppKit
import SwiftUI
import DrIslandCore

/// A round icon button; `filled` is the main action of a group (white disc, dark glyph).
struct CircleButton: View {
    let symbol: String
    var size: CGFloat = 26
    var filled = false
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(filled ? Color.black : Color.white.opacity(0.9))
                .frame(width: size, height: size)
                .background(Circle().fill(filled ? Color.white : Color.white.opacity(0.0)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
        .islandTip(help)
    }
}
