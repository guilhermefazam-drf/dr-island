import AppKit
import SwiftUI
import DrIslandCore

/// Today as columns of events per hour. «resumo» opens the briefing; «detalhes» opens the settings page with every event.
struct TimelineBlock: View {
    let counts: [Int]
    let showBriefing: () -> Void
    let openDetails: () -> Void
    @Environment(\.islandPalette) private var palette
    @Environment(\.islandMetrics) private var metrics

    nonisolated static let chartHeight: CGFloat = 54
    nonisolated static func contentHeight(_ m: IslandMetrics) -> CGFloat { CGFloat(m.cardHeader) + 6 + chartHeight }

    var body: some View {
        let total = counts.reduce(0, +)
        let hour = Calendar.current.component(.hour, from: Date())
        VStack(alignment: .leading, spacing: 6) {
            CardHeader(title: total == 0 ? "Hoje" : "Hoje · \(total) \(total == 1 ? "evento" : "eventos")",
                       icon: "chart.bar.xaxis", source: .timeline) {
                Button(action: showBriefing) { Text("resumo").foregroundStyle(Color(palette.info)) }
                    .buttonStyle(.plain).pointingHandCursor()
                    .islandTip("O que mudou desde a última vez que viste a ilha")
                Button(action: openDetails) { Text("detalhes").foregroundStyle(Color(palette.info)) }
                    .buttonStyle(.plain).pointingHandCursor()
                    .islandTip("Todos os eventos do dia, nas definições")
            }
            HourlyColumnChart(counts: counts, range: DayBriefing.hourRange(counts, endHour: hour), nowHour: hour, height: Self.chartHeight)
                .overlay {
                    if total == 0 {
                        Text("Ainda sem eventos hoje").font(.caption2).foregroundStyle(Color(palette.textSecondary)).padding(.bottom, 14)
                    }
                }
        }
        .frame(height: Self.contentHeight(metrics), alignment: .top)
        .blockCard()
    }
}
