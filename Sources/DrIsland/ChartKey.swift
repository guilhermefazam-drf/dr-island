import SwiftUI
import DrIslandCore

/// A chart's legend in its card header: a short line, a dashed line or a square in the series colour, then its name.
struct ChartKey: View {
    enum Mark { case line, dashed, square }
    struct Item {
        let label: String
        let color: Color
        var mark: Mark = .square
    }

    let items: [Item]
    @Environment(\.islandPalette) private var palette
    @Environment(\.islandMetrics) private var metrics

    var body: some View {
        HStack(spacing: 9) {
            ForEach(items, id: \.label) { item in
                HStack(spacing: 4) {
                    swatch(item)
                    Text(item.label).lineLimit(1)
                }
            }
        }
        .font(.system(size: CGFloat(metrics.metaSize)))
        .foregroundStyle(Color(palette.textSecondary))
        .accessibilityHidden(true)
    }

    @ViewBuilder private func swatch(_ item: Item) -> some View {
        switch item.mark {
        case .square:
            RoundedRectangle(cornerRadius: 2).fill(item.color).frame(width: 8, height: 8)
        case .line:
            Capsule().fill(item.color).frame(width: 10, height: 2)
        case .dashed:
            HStack(spacing: 2) { ForEach(0..<3, id: \.self) { _ in Capsule().fill(item.color).frame(width: 2.5, height: 1.5) } }
                .frame(width: 11)
        }
    }
}
