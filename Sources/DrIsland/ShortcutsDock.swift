import SwiftUI
import DrIslandCore

/// The pinned apps under the columns, centred, on a snug pill (not a full card). The icon under the pointer grows
/// a little; the others stay put.
struct ShortcutsDock: View {
    let shortcuts: [DevShortcut]
    @State private var hovered: String?
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

    /// How much the icon under the pointer grows.
    private static let hoverScale: CGFloat = 1.12

    /// The dock's full height (the pill around one row of icons).
    nonisolated static func height(_ m: IslandMetrics) -> CGFloat { CGFloat(m.dockIcon) + 2 * vertical(m) }

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(shortcuts, id: \.id) { shortcut in
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
                .scaleEffect(hovered == shortcut.id && !reduceMotion ? Self.hoverScale : 1)
                .animation(.spring(response: 0.25, dampingFraction: 0.75), value: hovered)
                .onHover { inside in
                    if inside { hovered = shortcut.id } else if hovered == shortcut.id { hovered = nil }
                }
                .islandTip(shortcut.folder.map { "\(shortcut.name) · \(($0 as NSString).lastPathComponent)" } ?? shortcut.name)
            }
        }
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
}
