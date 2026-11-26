import SwiftUI
import DrIslandCore

/// Someone else's initials in a coloured circle (the same colour for the same person); the full name is the tooltip.
/// Hidden on the user's own rows and when «mostrar dono» is off, like the old owner tag.
struct Avatar: View {
    let name: String?
    let isMine: Bool
    @AppStorage(SettingsKey.showOwner) private var showOwner = true
    @Environment(\.islandPalette) private var palette
    @Environment(\.islandMetrics) private var metrics

    private static let hues: [Color] = [
        Color(red: 0.49, green: 0.36, blue: 1.00), Color(red: 0.88, green: 0.38, blue: 0.17),
        Color(red: 0.12, green: 0.62, blue: 0.55), Color(red: 0.76, green: 0.25, blue: 0.48),
        Color(red: 0.23, green: 0.51, blue: 0.96), Color(red: 0.80, green: 0.55, blue: 0.10),
        Color(red: 0.36, green: 0.62, blue: 0.24), Color(red: 0.55, green: 0.40, blue: 0.80),
    ]

    var body: some View {
        if showOwner, let label = Owner.label(name: name, isMine: isMine) {
            let size = CGFloat(metrics.tile) - (metrics.rowHasMeta ? 4 : 2)
            Text(label)
                .font(.system(size: size * 0.45, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Circle().fill(Self.hues[AvatarColor.index(for: name ?? "", count: Self.hues.count)]))
                .islandTip(name ?? "")
                .accessibilityLabel(name ?? label)
        }
    }
}
