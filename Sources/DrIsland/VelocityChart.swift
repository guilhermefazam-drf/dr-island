import SwiftUI
import Charts
import DrIslandCore

/// Each sprint as a faint bar for what was planned with a slimmer one inside for what was finished, so the gap between
/// them reads at a glance; the average is a hairline labelled at its end. Hovering a sprint shows its numbers.
struct VelocityChart: View {
    @Environment(\.islandPalette) private var palette
    let result: VelocityResult
    @State private var hovered: String?

    var body: some View {
        let scale = ChartScale.nice(maxValue: result.sprints.map { max($0.planned, $0.completed) }.max() ?? 0)
        let accent = Color(palette.accent)
        let selected = hovered.flatMap { name in result.sprints.first { $0.shortName == name } }
        Chart {
            ForEach(result.sprints) { sprint in
                let dimmed = selected != nil && selected?.id != sprint.id
                // Explicit start and end: two marks on one x would otherwise stack instead of overlapping.
                BarMark(x: .value("Sprint", sprint.shortName), yStart: .value("Base", 0), yEnd: .value("Planeado", sprint.planned), width: .fixed(18))
                    .foregroundStyle(Color(palette.neutral).opacity(dimmed ? 0.12 : 0.24))
                    .cornerRadius(4)
                BarMark(x: .value("Sprint", sprint.shortName), yStart: .value("Base", 0), yEnd: .value("Concluído", sprint.completed), width: .fixed(8))
                    .foregroundStyle(accent.opacity(dimmed ? 0.45 : 1))
                    .cornerRadius(3)
            }
            RuleMark(y: .value("Média", result.averageCompleted))
                .foregroundStyle(Color(palette.textSecondary).opacity(0.7))
                .lineStyle(StrokeStyle(lineWidth: 1))
                .annotation(position: .trailing, alignment: .center, spacing: 4) {
                    Text("média\n\(VelocityChart.format(result.averageCompleted))").multilineTextAlignment(.leading)
                        .font(.system(size: 9, weight: .medium)).foregroundStyle(Color(palette.textSecondary))
                }
            if let sprint = selected {
                RuleMark(x: .value("Sprint", sprint.shortName))
                    .foregroundStyle(.clear)
                    .annotation(position: .top, spacing: 0, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                        ChartTooltip(title: sprint.name, lines: [
                            .init(label: "Planeado", value: Self.format(sprint.planned), color: Color(palette.neutral).opacity(0.5)),
                            .init(label: "Concluído", value: Self.format(sprint.completed), color: accent),
                        ])
                    }
            }
        }
        .chartYScale(domain: 0...scale.top)
        .chartPlotStyle { plot in plot.padding(.trailing, 30) }   // the average's label sits past the bars
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks { AxisValueLabel().font(.system(size: 9)).foregroundStyle(Color(palette.textTertiary)) }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: scale.ticks) {
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color(palette.text).opacity(0.08))
                AxisValueLabel().font(.system(size: 9)).foregroundStyle(Color(palette.textTertiary))
            }
        }
        .chartHover($hovered)
        .accessibilityElement()
        .accessibilityLabel("Velocity das últimas \(result.sprints.count) sprints, média \(Self.format(result.averageCompleted))")
    }

    static func format(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0...1))) }
}
