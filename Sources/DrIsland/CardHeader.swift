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
        HStack(spacing: 8) {
            SourceTile(icon: icon, source: source)
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
