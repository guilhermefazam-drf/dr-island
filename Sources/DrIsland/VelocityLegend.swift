import SwiftUI
import DrIslandCore

/// What the bars and the line of the velocity chart mean.
struct VelocityLegend: View {
    @Environment(\.islandPalette) private var palette

    var body: some View {
        HStack(spacing: 10) {
            key(Color(palette.neutral).opacity(0.35), "Planeado")
            key(Color(palette.accent), "Concluído")
            HStack(spacing: 4) {
                Rectangle().fill(Color(palette.textSecondary).opacity(0.7)).frame(width: 10, height: 1)
                Text("Média").font(.caption2).foregroundStyle(Color(palette.textSecondary))
            }
        }
        .frame(height: 14)
        .accessibilityHidden(true)
    }

    private func key(_ color: Color, _ title: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 8, height: 8)
            Text(title).font(.caption2).foregroundStyle(Color(palette.textSecondary))
        }
    }
}
