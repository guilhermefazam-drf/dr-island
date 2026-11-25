import SwiftUI
import DrIslandCore

/// One status of the flow card: its name, a bar for how much sits in it and how long work stays there.
struct FlowBarRow: View {
    @Environment(\.islandPalette) private var palette
    let row: FlowStatusRow
    let largest: Double

    var body: some View {
        HStack(spacing: 6) {
            Text(row.name).font(.caption2).foregroundStyle(Color(palette.textSecondary)).lineLimit(1).truncationMode(.tail)
                .frame(width: 76, alignment: .leading)
            GeometryReader { proxy in
                Capsule().fill(color).frame(width: max(3, proxy.size.width * share), height: 6)
                    .frame(maxHeight: .infinity, alignment: .center)
            }
            Text(row.amount.formatted(.number.precision(.fractionLength(0...1))))
                .font(.caption2.monospacedDigit()).foregroundStyle(Color(palette.text).opacity(0.85))
                .frame(width: 26, alignment: .trailing)
            Text(row.medianDays.map { "~\($0.formatted(.number.precision(.fractionLength(0...1)))) d" } ?? "—")
                .font(.caption2.monospacedDigit()).foregroundStyle(Color(palette.textSecondary))
                .frame(width: 40, alignment: .trailing)
        }
        .frame(height: IslandLayout.managementFlowRow)
        .accessibilityElement(children: .combine)
    }

    private var share: Double { largest > 0 ? row.amount / largest : 0 }

    private var color: Color {
        switch row.category {
        case "done": return Color(palette.green)
        case "new": return Color(palette.neutral).opacity(0.7)
        default: return Color(palette.accent)
        }
    }
}
