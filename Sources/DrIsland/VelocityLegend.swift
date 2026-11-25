import SwiftUI
import DrIslandCore

/// What the bars and the line of the velocity chart mean.
struct VelocityLegend: View {
    @Environment(\.islandPalette) private var palette
    private var items: [(title: String, color: Color)] {
        [("Planeado", Color(palette.neutral).opacity(0.6)), ("Concluído", Color(palette.accent)), ("Média", Color(palette.green))]
    }

    var body: some View {
        HStack(spacing: 10) {
            ForEach(items, id: \.title) { item in
                HStack(spacing: 4) {
                    Rectangle().fill(item.color).frame(width: 8, height: 8).clipShape(RoundedRectangle(cornerRadius: 2))
                    Text(item.title).font(.caption2).foregroundStyle(Color(palette.textSecondary))
                }
            }
        }
        .frame(height: 14)
        .accessibilityHidden(true)
    }
}
