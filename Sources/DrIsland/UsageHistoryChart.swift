import SwiftUI
import DrIslandCore

/// Peak session usage for the last 14 days: the first seven (dimmer) are the previous week, for comparison.
struct UsageHistoryChart: View {
    let history: [DayUsage]
    /// The amber and red limits (percentages), so each bar has the colour it had that day.
    let amber: Double
    let red: Double
    @Environment(\.islandPalette) private var palette
    @Environment(\.islandMetrics) private var metrics

    nonisolated static func contentHeight(_ m: IslandMetrics) -> CGFloat { CGFloat(m.cardHeader) + 6 + IslandLayout.historyContent }

    var body: some View {
        let days = UsageHistory.lastDays(14, from: history)
        VStack(alignment: .leading, spacing: 6) {
            CardHeader(title: "Uso · 14 dias", icon: "chart.bar", source: .history)
            chart(days)
        }
        .frame(height: Self.contentHeight(metrics), alignment: .top)
        .blockCard()
    }

    private func chart(_ days: [(date: Date, usage: DayUsage?)]) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(days.enumerated()), id: \.element.date) { index, entry in
                    let peak = entry.usage?.sessionPeak
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Capsule()
                            .fill(peak.map { Brand.color(forFraction: $0, amber: amber, red: red, palette: palette) } ?? Color(palette.text).opacity(0.12))
                            .opacity(index < 7 ? 0.5 : 1)
                            .frame(height: max(3, 28 * (peak ?? 0)))
                            .frame(maxWidth: 16)
                    }
                    .frame(maxWidth: .infinity, minHeight: 28, maxHeight: 28)
                    .islandTip("\(entry.date.formatted(.dateTime.weekday(.wide).day().month())): \(peak.map { "\(Int(($0 * 100).rounded()))%" } ?? "sem dados")")
                }
            }
            HStack(spacing: 3) {
                ForEach(days, id: \.date) { entry in
                    Text(entry.date.formatted(.dateTime.weekday(.narrow)))
                        .font(.system(size: 8)).foregroundStyle(Color(palette.textSecondary)).frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: IslandLayout.historyContent, alignment: .bottom)
    }
}
