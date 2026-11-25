import SwiftUI
import Charts
import DrIslandCore

/// Bugs created and resolved, week by week.
struct BugsChart: View {
    @Environment(\.islandPalette) private var palette
    let weeks: [BugWeek]

    var body: some View {
        Chart {
            ForEach(weeks) { week in
                BarMark(x: .value("Semana", week.start, unit: .weekOfYear), y: .value("Criados", week.created), width: .ratio(0.7))
                    .foregroundStyle(Color(palette.red)).position(by: .value("Tipo", "Criados"))
                BarMark(x: .value("Semana", week.start, unit: .weekOfYear), y: .value("Resolvidos", week.resolved), width: .ratio(0.7))
                    .foregroundStyle(Color(palette.green)).position(by: .value("Tipo", "Resolvidos"))
            }
        }
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfYear, count: 2)) {
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
        .accessibilityLabel("Bugs criados e resolvidos por semana, nas últimas \(weeks.count) semanas")
    }
}
