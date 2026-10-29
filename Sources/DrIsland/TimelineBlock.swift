import AppKit
import SwiftUI
import DrIslandCore

/// Today as a line chart of events per hour. «resumo» opens the briefing; «detalhes» opens the settings page with every event.
struct TimelineBlock: View {
    let counts: [Int]
    let showBriefing: () -> Void
    let openDetails: () -> Void

    nonisolated static let chartHeight: CGFloat = 54
    nonisolated static var contentHeight: CGFloat { IslandLayout.alertsHeader + 6 + chartHeight }

    var body: some View {
        let total = counts.reduce(0, +)
        let hour = Calendar.current.component(.hour, from: Date())
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Label(total == 0 ? "Hoje" : "Hoje · \(total) \(total == 1 ? "evento" : "eventos")", systemImage: "chart.xyaxis.line")
                    .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                Spacer()
                Button(action: showBriefing) { Text("resumo").font(.caption2).foregroundStyle(linkBlue) }
                    .buttonStyle(.plain).pointingHandCursor()
                    .islandTip("O que mudou desde a última vez que viste a ilha")
                Button(action: openDetails) { Text("detalhes").font(.caption2).foregroundStyle(linkBlue) }
                    .buttonStyle(.plain).pointingHandCursor()
                    .islandTip("Todos os eventos do dia, nas definições")
            }
            .frame(height: IslandLayout.alertsHeader)
            HourlyLineChart(counts: counts, range: DayBriefing.hourRange(counts, endHour: hour), nowHour: hour, height: Self.chartHeight)
                .overlay {
                    if total == 0 {
                        Text("Ainda sem eventos hoje").font(.caption2).foregroundStyle(.secondary).padding(.bottom, 14)
                    }
                }
        }
        .frame(height: Self.contentHeight, alignment: .top)
        .blockCard()
    }
}
