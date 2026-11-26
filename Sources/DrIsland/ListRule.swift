import SwiftUI
import DrIslandCore

/// The thin line between two lists of a card.
struct ListRule: View {
    @Environment(\.islandPalette) private var palette
    @Environment(\.islandMetrics) private var metrics

    var body: some View {
        Rectangle().fill(Color(palette.text).opacity(0.08)).frame(height: 1).padding(.vertical, (CGFloat(metrics.listRule) - 1) / 2)
    }
}
