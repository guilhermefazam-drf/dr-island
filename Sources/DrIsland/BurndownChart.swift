import SwiftUI
import Charts
import DrIslandCore

/// Remaining work, ideal line, scope and today's marker, drawn for the island's black background.
struct BurndownChart: View {
    let result: BurndownResult

    var body: some View {
        let today = Calendar.current.startOfDay(for: Date())
        let first = result.points.first?.date, last = result.points.last?.date
        Chart {
            ForEach(result.points, id: \.date) { point in
                LineMark(x: .value("Dia", point.date), y: .value("Âmbito", point.scope), series: .value("Série", "Âmbito"))
                    .foregroundStyle(Color.gray.opacity(0.6)).interpolationMethod(.stepEnd)
                LineMark(x: .value("Dia", point.date), y: .value("Ideal", point.ideal), series: .value("Série", "Ideal"))
                    .foregroundStyle(Color.secondary).lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                LineMark(x: .value("Dia", point.date), y: .value("Por fazer", point.remaining), series: .value("Série", "Por fazer"))
                    .foregroundStyle(Brand.blue).lineStyle(StrokeStyle(lineWidth: 2.2))
                PointMark(x: .value("Dia", point.date), y: .value("Por fazer", point.remaining))
                    .foregroundStyle(Brand.blue).symbolSize(14)
            }
            if let first, let last, today >= first, today <= last {
                RuleMark(x: .value("Hoje", today)).foregroundStyle(Brand.amber.opacity(0.7))
                    .annotation(position: .top, alignment: .leading) { Text("hoje").font(.caption2).foregroundStyle(Brand.amber) }
            }
        }
        .chartYScale(domain: .automatic(includesZero: true))
        .chartPlotStyle { plot in plot.padding(.trailing, 14) }   // room for the last date label
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 3)) {
                AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                AxisValueLabel(format: .dateTime.day().month(.abbreviated)).font(.caption2).foregroundStyle(Color.secondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) {
                AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                AxisValueLabel().font(.caption2).foregroundStyle(Color.secondary)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Burndown da sprint: \(BurndownSummary.doneText(result)), \(BurndownSummary.flaggedText(result))")
    }
}
