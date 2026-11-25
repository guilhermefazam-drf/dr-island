import SwiftUI
import DrIslandCore

/// A card's title row: a tile in the block's source colour, the title, an optional count and an accessory at the
/// right end (tabs, the sprint bar, «ver tudo», «reinicia em…»).
struct CardHeader<Accessory: View>: View {
    let title: String
    let icon: String
    let source: IslandBlock
    var count: Int?
    @ViewBuilder var accessory: Accessory
    @Environment(\.islandPalette) private var palette
    @Environment(\.islandMetrics) private var metrics

    init(title: String, icon: String, source: IslandBlock, count: Int? = nil, @ViewBuilder accessory: () -> Accessory = { EmptyView() }) {
        self.title = title
        self.icon = icon
        self.source = source
        self.count = count
        self.accessory = accessory()
    }

    var body: some View {
        let tile = CGFloat(metrics.tile)
        let colour = Color(palette.source(source))
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: tile * 0.55, weight: .semibold))
                .foregroundStyle(colour)
                .frame(width: tile, height: tile)
                .background(RoundedRectangle(cornerRadius: tile * 0.3, style: .continuous).fill(colour.opacity(0.2)))
                .accessibilityHidden(true)
            Text(title)
                .font(.system(size: CGFloat(metrics.titleSize), weight: .semibold))
                .foregroundStyle(Color(palette.text))
                .lineLimit(1)
            if let count {
                Text("\(count)")
                    .font(.system(size: CGFloat(metrics.metaSize)).monospacedDigit())
                    .foregroundStyle(Color(palette.textSecondary))
                    .padding(.horizontal, 7)
                    .background(Capsule().fill(Color(palette.surfaceRaised)))
            }
            Spacer(minLength: 6)
            accessory
                .font(.system(size: CGFloat(metrics.metaSize)))
                .foregroundStyle(Color(palette.textSecondary))
        }
        .frame(height: CGFloat(metrics.cardHeader))
        .accessibilityElement(children: .contain)
    }
}
