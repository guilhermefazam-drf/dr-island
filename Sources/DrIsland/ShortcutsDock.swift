import SwiftUI
import DrIslandCore

/// The pinned apps under the columns, centred. Like the Dock, the icon under the pointer grows and its neighbours follow.
struct ShortcutsDock: View {
    let shortcuts: [DevShortcut]
    @State private var pointerX: CGFloat?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let icon: CGFloat = 26
    private static let spacing: CGFloat = 14

    var body: some View {
        HStack(spacing: Self.spacing) {
            ForEach(Array(shortcuts.enumerated()), id: \.element.id) { index, shortcut in
                Button { ShortcutLauncher.open(shortcut) } label: {
                    Image(nsImage: AppIcons.icon(forFile: shortcut.appPath))
                        .resizable().interpolation(.high).frame(width: Self.icon, height: Self.icon)
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
                // Anchored to the bottom, so a grown icon rises out of the row.
                .scaleEffect(scale(at: index), anchor: .bottom)
                .offset(y: -(scale(at: index) - 1) * 4)
                .islandTip(shortcut.folder.map { "\(shortcut.name) · \(($0 as NSString).lastPathComponent)" } ?? shortcut.name)
            }
        }
        .coordinateSpace(.named("dock"))
        .onContinuousHover(coordinateSpace: .named("dock"), perform: track)
        .frame(height: IslandLayout.shortcutsContent, alignment: .bottom)
        .blockCard()
        .fixedSize()
        .frame(maxWidth: .infinity)   // centred under the columns
    }

    private func track(_ phase: HoverPhase) {
        switch phase {
        case .active(let point): withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) { pointerX = point.x }
        case .ended: withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { pointerX = nil }
        }
    }

    /// 1 at rest, up to 1.7 right under the pointer, falling off smoothly over about two icons.
    private func scale(at index: Int) -> CGFloat {
        guard let x = pointerX, !reduceMotion else { return 1 }
        let center = Self.icon / 2 + CGFloat(index) * (Self.icon + Self.spacing)
        let distance = abs(x - center)
        return 1 + 0.7 * exp(-pow(distance / 36, 2))
    }
}
