import SwiftUI
import DrIslandCore

/// The small rounded square in a block's source colour with its symbol (card headers, Bento numbers and strip).
struct SourceTile: View {
    let icon: String
    let source: IslandBlock
    @Environment(\.islandPalette) private var palette
    @Environment(\.islandMetrics) private var metrics

    var body: some View {
        let tile = CGFloat(metrics.tile)
        let colour = Color(palette.source(source))
        Image(systemName: icon)
            .font(.system(size: tile * 0.55, weight: .semibold))
            .foregroundStyle(colour)
            .frame(width: tile, height: tile)
            .background(RoundedRectangle(cornerRadius: tile * 0.3, style: .continuous).fill(colour.opacity(0.2)))
            .accessibilityHidden(true)
    }
}
