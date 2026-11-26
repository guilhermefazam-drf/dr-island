import SwiftUI
import DrIslandCore

/// A card's title row; with a sprint, its progress bar sits at the right end and the tooltip has the details.
struct CardTitle: View {
    let title: String
    let icon: String
    var sprint: SprintInfo?
    var onManagement: (() -> Void)?
    @Environment(\.islandPalette) private var palette
    @Environment(\.islandMetrics) private var metrics

    var body: some View {
        HStack(spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold)).foregroundStyle(Color(palette.textSecondary)).lineLimit(1)
            Spacer(minLength: 6)
            if let onManagement {
                Button(action: onManagement) { Image(systemName: "chart.xyaxis.line").font(.caption) }
                    .buttonStyle(.plain).foregroundStyle(Color(palette.textSecondary)).islandTip("Gestão")
            }
            if let sprint { SprintBar(sprint: sprint) }
        }
        .frame(height: CGFloat(metrics.cardHeader) - 4)
        .padding(.bottom, 4)
        .contentShape(Rectangle())
        .islandTip(sprint.map { SprintBar.tooltip($0) } ?? "")
    }
}
