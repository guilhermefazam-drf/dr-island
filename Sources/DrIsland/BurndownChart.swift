import SwiftUI
import Charts
import DrIslandCore

/// Remaining work, ideal line, scope and today's marker, drawn for the island's black background.
struct BurndownChart: View {
    @Environment(\.islandPalette) private var palette
    let result: BurndownResult

    var body: some View {
        let today = Calendar.current.startOfDay(for: Date())
        let first = result.points.first?.date, last = result.points.last?.date
        Chart {
            ForEach(result.points, id: \.date) { point in
                LineMark(x: .value("Dia", point.date), y: .value("Âmbito", point.scope), series: .value("Série", "Âmbito"))
                    .foregroundStyle(Color(palette.neutral).opacity(0.6)).interpolationMethod(.stepEnd)
                LineMark(x: .value("Dia", point.date), y: .value("Ideal", point.ideal), series: .value("Série", "Ideal"))
                    .foregroundStyle(Color(palette.textSecondary)).lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                LineMark(x: .value("Dia", point.date), y: .value("Por fazer", point.remaining), series: .value("Série", "Por fazer"))
                    .foregroundStyle(Color(palette.accent)).lineStyle(StrokeStyle(lineWidth: 2.2))
                PointMark(x: .value("Dia", point.date), y: .value("Por fazer", point.remaining))
                    .foregroundStyle(Color(palette.accent)).symbolSize(14)
            }
            if let first, let last, today >= first, today <= last {
                RuleMark(x: .value("Hoje", today)).foregroundStyle(Color(palette.amber).opacity(0.7))
                    .annotation(position: .top, alignment: .leading) { Text("hoje").font(.caption2).foregroundStyle(Color(palette.amber)) }
            }
        }
        .chartYScale(domain: .automatic(includesZero: true))
        .chartPlotStyle { plot in plot.padding(.trailing, 14) }   // room for the last date label
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 3)) {
                AxisGridLine().foregroundStyle(Color(palette.text).opacity(0.08))
                AxisValueLabel(format: .dateTime.day().month(.abbreviated)).font(.caption2).foregroundStyle(Color(palette.textSecondary))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) {
                AxisGridLine().foregroundStyle(Color(palette.text).opacity(0.08))
                AxisValueLabel().font(.caption2).foregroundStyle(Color(palette.textSecondary))
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Burndown da sprint: \(BurndownSummary.doneText(result)), \(BurndownSummary.flaggedText(result))")
    }
}
