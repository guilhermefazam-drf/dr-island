import SwiftUI
import DrIslandCore

/// A small preview of a theme for the picker in «Aparência»: the island's base with a card and an accent dot.
struct ThemeThumbnail: View {
    let theme: IslandTheme
    let selected: Bool

    var body: some View {
        let palette = theme.palette
        let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        IslandBackground(theme: theme, palette: palette, collarHeight: 7, reduceTransparency: false)
            .frame(width: 64, height: 40)
            .overlay(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color(palette.surface))
                    .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(Color(palette.border), lineWidth: 0.5))
                    .overlay(alignment: .topLeading) {
                        HStack(spacing: 3) {
                            Circle().fill(Color(palette.accent)).frame(width: 5, height: 5)
                            Capsule().fill(Color(palette.text).opacity(0.7)).frame(width: 18, height: 3)
                        }
                        .padding(4)
                    }
                    .frame(width: 44, height: 22)
                    .padding(6)
            }
            .clipShape(shape)
            .overlay(shape.stroke(selected ? Color(palette.accent) : Color.primary.opacity(0.15), lineWidth: selected ? 2 : 1))
            .accessibilityElement()
            .accessibilityLabel(theme.title)
            .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}
