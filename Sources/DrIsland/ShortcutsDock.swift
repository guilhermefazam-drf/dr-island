import SwiftUI
import DrIslandCore

/// The pinned apps under the columns, centred, on a snug pill (not a full card). Like the Dock, the icon under the
/// pointer grows out of the pill and its neighbours follow.
struct ShortcutsDock: View {
    let shortcuts: [DevShortcut]
    @State private var pointerX: CGFloat?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.islandMetrics) private var metrics
    @Environment(\.islandPalette) private var palette

    private var icon: CGFloat { CGFloat(metrics.dockIcon) }
    private var spacing: CGFloat { Self.spacing(metrics) }

    // The pill: 6/8 pt padding, 16 pt corners and 8 pt between icons at Normal; 4/6, 12 and 6 at Compacto.
    nonisolated private static func vertical(_ m: IslandMetrics) -> CGFloat { m.rowHasMeta ? 6 : 4 }
    nonisolated private static func horizontal(_ m: IslandMetrics) -> CGFloat { m.rowHasMeta ? 8 : 6 }
    nonisolated private static func radius(_ m: IslandMetrics) -> CGFloat { m.rowHasMeta ? 16 : 12 }
    nonisolated private static func spacing(_ m: IslandMetrics) -> CGFloat { m.rowHasMeta ? 8 : 6 }

    /// Share of an app icon's canvas taken by its artwork (Apple's icon grid: 824 of 1024 pt).
    private static let artwork: CGFloat = 824.0 / 1024.0

    /// The dock's full height (the pill around one row of icons); a grown icon rises above it.
    nonisolated static func height(_ m: IslandMetrics) -> CGFloat { CGFloat(m.dockIcon) + 2 * vertical(m) }

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(Array(shortcuts.enumerated()), id: \.element.id) { index, shortcut in
                Button { ShortcutLauncher.open(shortcut) } label: {
                    // macOS app icons carry a transparent margin (the artwork is ~82% of the canvas), so the image
                    // is drawn larger than its slot for the visible icon to fill it, as in the design.
                    Image(nsImage: AppIcons.icon(forFile: shortcut.appPath))
                        .resizable().interpolation(.high)
                        .frame(width: icon / Self.artwork, height: icon / Self.artwork)
                        .frame(width: icon, height: icon)
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
        .frame(height: icon)
        .padding(.vertical, Self.vertical(metrics))
        .padding(.horizontal, Self.horizontal(metrics))
        .background {
            let shape = RoundedRectangle(cornerRadius: Self.radius(metrics), style: .continuous)
            shape.fill(Color(palette.surface))
                .overlay(shape.strokeBorder(Color(palette.border), lineWidth: 1))
                .overlay(alignment: .top) {
                    Rectangle().fill(Color(palette.highlight)).frame(height: 1).padding(.horizontal, Self.radius(metrics) * 0.6)
                }
                .shadow(color: .black.opacity(palette.isLight ? 0.05 : 0), radius: 14, y: 4)
        }
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
        let center = icon / 2 + CGFloat(index) * (icon + spacing)
        let distance = abs(x - center)
        return 1 + 0.7 * exp(-pow(distance / 36, 2))
    }
}
