import SwiftUI

/// What the three lines of the burndown mean.
struct BurndownLegend: View {
    private static let items: [(title: String, color: Color, dashed: Bool)] = [
        ("Por fazer", Brand.blue, false), ("Ideal", Color.secondary, true), ("Âmbito", Color.gray.opacity(0.6), false),
    ]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Self.items, id: \.title) { item in
                HStack(spacing: 4) {
                    Rectangle().fill(item.color).frame(width: 10, height: item.dashed ? 1 : 2)
                        .mask { HStack(spacing: item.dashed ? 2 : 0) { ForEach(0..<(item.dashed ? 3 : 1), id: \.self) { _ in Rectangle() } } }
                    Text(item.title).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityHidden(true)
    }
}
