import SwiftUI
import Charts
import DrIslandCore

/// Bugs created and resolved, week by week.
struct BugsChart: View {
    let weeks: [BugWeek]

    var body: some View {
        Chart {
            ForEach(weeks) { week in
                BarMark(x: .value("Semana", week.start, unit: .weekOfYear), y: .value("Criados", week.created), width: .ratio(0.7))
                    .foregroundStyle(Brand.red).position(by: .value("Tipo", "Criados"))
                BarMark(x: .value("Semana", week.start, unit: .weekOfYear), y: .value("Resolvidos", week.resolved), width: .ratio(0.7))
                    .foregroundStyle(Brand.green).position(by: .value("Tipo", "Resolvidos"))
            }
        }
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfYear, count: 2)) {
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
        .accessibilityLabel("Bugs criados e resolvidos por semana, nas últimas \(weeks.count) semanas")
    }
}
