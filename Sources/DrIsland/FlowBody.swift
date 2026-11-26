import SwiftUI
import DrIslandCore

/// The segmented bar, its key (Normal only) and the tasks stuck the longest, as many as fit in the card.
struct FlowBody: View {
    let result: FlowResult
    let unit: String
    @Environment(\.islandPalette) private var palette
    @Environment(\.islandMetrics) private var metrics

    private var barHeight: CGFloat { metrics.rowHasMeta ? 24 : 20 }
    private static let keyHeight: CGFloat = 40
    private static let sublabelHeight: CGFloat = 16

    var body: some View {
        if result.rows.isEmpty {
            ListNote(text: "Sem tasks nesta sprint")
        } else {
            let groups = FlowGroup.groups(result.rows)
            VStack(alignment: .leading, spacing: 8) {
                FlowSegmentBar(groups: groups, height: barHeight)
                if metrics.rowHasMeta { key(groups) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.stuck.isEmpty ? "Nada parado há mais de \(Int(FlowMetrics.stuckDays)) dias" : "Paradas há mais tempo · \(result.stuck.count)")
                        .font(.system(size: CGFloat(metrics.metaSize), weight: .semibold))
                        .foregroundStyle(Color(palette.textSecondary))
                        .frame(height: Self.sublabelHeight)
                    ForEach(result.stuck.prefix(rowsThatFit)) { FlowStuckRow(task: $0) }
                }
            }
        }
    }

    /// The card's content area (chart plus the summary row it does not use) minus the bar, the key and the sublabel.
    private var rowsThatFit: Int {
        let room = IslandLayout.managementChart(metrics) + 8 + IslandLayout.managementSummary
        let used = barHeight + 8 + (metrics.rowHasMeta ? Self.keyHeight + 8 : 0) + Self.sublabelHeight + 2
        return max(Int((room - used) / FlowStuckRow.height(metrics)), 0)
    }

    private func key(_ groups: [FlowGroup]) -> some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(groups) { group in
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 2).fill(group.keyColor(palette)).frame(width: 8, height: 8)
                        Text(group.name).foregroundStyle(Color(palette.textSecondary))
                    }
                    .font(.system(size: CGFloat(metrics.metaSize)))
                    Text("\(ManagementKPIs.format(group.amount)) \(unit)")
                        .font(.system(size: CGFloat(metrics.bodySize), weight: .semibold).monospacedDigit())
                        .foregroundStyle(Color(palette.text))
                    Text(group.days.map { "~\(ManagementKPIs.format($0)) d em média" } ?? " ")
                        .font(.system(size: CGFloat(metrics.metaSize) - 1).monospacedDigit())
                        .foregroundStyle(Color(palette.textTertiary))
                }
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(height: Self.keyHeight, alignment: .top)
    }
}
