import SwiftUI
import DrIslandCore

/// Theme surface, hairline border, a light line along the top edge and, on light themes, a soft shadow.
/// Padding and corner radius come from the density.
struct BlockCardStyle: ViewModifier {
    let active: Bool
    @Environment(\.islandPalette) private var palette
    @Environment(\.islandMetrics) private var metrics

    func body(content: Content) -> some View {
        let radius = CGFloat(metrics.cardRadius)
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .padding(CGFloat(metrics.cardPadding))
            .background {
                shape.fill(active ? Color(palette.accent).opacity(0.14) : Color(palette.surface))
                    .shadow(color: .black.opacity(palette.isLight ? 0.05 : 0), radius: 14, y: 4)
            }
            .overlay {
                shape.strokeBorder(active ? Color(palette.accent).opacity(0.35) : Color(palette.border), lineWidth: 1)
            }
            .overlay(alignment: .top) {
                if !active {
                    // The light catching the card's top edge, kept inside the rounded corners.
                    Rectangle().fill(Color(palette.highlight)).frame(height: 1).padding(.horizontal, radius * 0.6)
                }
            }
    }
}
