import SwiftUI
import DrIslandCore

/// A clickable "+N mais" / "mostrar menos" row.
struct ListExpander: View {
    let title: String
    let action: () -> Void
    @Environment(\.islandPalette) private var palette
    @Environment(\.islandMetrics) private var metrics

    var body: some View {
        Button(action: action) {
            Text(title).font(.caption2.weight(.medium)).foregroundStyle(Color(palette.info))
                .frame(maxWidth: .infinity, minHeight: CGFloat(metrics.rowHeight), maxHeight: CGFloat(metrics.rowHeight), alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
