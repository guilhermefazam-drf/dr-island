import SwiftUI
import Charts
import DrIslandCore

/// Planned against finished, sprint by sprint, with the average as a line.
struct VelocityChart: View {
    let result: VelocityResult

    var body: some View {
        Chart {
            ForEach(result.sprints) { sprint in
                BarMark(x: .value("Sprint", sprint.shortName), y: .value("Planeado", sprint.planned), width: .ratio(0.7))
                    .foregroundStyle(Color.gray.opacity(0.6)).position(by: .value("Tipo", "Planeado"))
                BarMark(x: .value("Sprint", sprint.shortName), y: .value("Concluído", sprint.completed), width: .ratio(0.7))
                    .foregroundStyle(Brand.blue).position(by: .value("Tipo", "Concluído"))
            }
            RuleMark(y: .value("Média", result.averageCompleted))
                .foregroundStyle(Brand.green.opacity(0.8)).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
        }
        .chartLegend(.hidden)
        .chartXAxis { AxisMarks { AxisValueLabel().font(.caption2).foregroundStyle(Color.secondary) } }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) {
                AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                AxisValueLabel().font(.caption2).foregroundStyle(Color.secondary)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Velocity das últimas \(result.sprints.count) sprints, média \(result.averageCompleted.formatted(.number.precision(.fractionLength(0...1))))")
    }
}
