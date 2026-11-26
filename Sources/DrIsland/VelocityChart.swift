import SwiftUI
import Charts
import DrIslandCore

/// Each sprint as a faint wide bar for what was planned with a slim one inside for what was finished, so the gap reads
/// at a glance; the average is a hairline labelled past the bars and the latest sprint carries its value. Hovering a
/// sprint shows its numbers.
struct VelocityChart: View {
    @Environment(\.islandPalette) private var palette
    let result: VelocityResult
    @State private var hovered: String?

    var body: some View {
        let scale = ChartScale.nice(maxValue: result.sprints.map { max($0.planned, $0.completed) }.max() ?? 0)
        let accent = Color(palette.accent)
        let selected = hovered.flatMap { name in result.sprints.first { $0.shortName == name } }
        let latest = result.sprints.last
        Chart {
            ForEach(result.sprints) { sprint in
                let dimmed = selected != nil && selected?.id != sprint.id
                // Explicit start and end: two marks on one x would otherwise stack instead of overlapping.
                BarMark(x: .value("Sprint", sprint.shortName), yStart: .value("Base", 0), yEnd: .value("Planeado", sprint.planned), width: .fixed(20))
                    .foregroundStyle(Color(palette.text).opacity(dimmed ? 0.06 : 0.11))
                    .cornerRadius(5)
                BarMark(x: .value("Sprint", sprint.shortName), yStart: .value("Base", 0), yEnd: .value("Concluído", sprint.completed), width: .fixed(8))
                    .foregroundStyle(accent.opacity(dimmed ? 0.4 : 1))
                    .cornerRadius(3)
                    .annotation(position: .top, spacing: 3) {
                        if sprint.id == latest?.id, selected == nil, sprint.completed >= sprint.planned {
                            Text(VelocityChart.format(sprint.completed)).font(.system(size: 10.5, weight: .semibold)).foregroundStyle(Color(palette.text))
                        }
                    }
            }
            RuleMark(y: .value("Média", result.averageCompleted))
                .foregroundStyle(Color(palette.textSecondary).opacity(0.75))
                .lineStyle(StrokeStyle(lineWidth: 1))
                .annotation(position: .trailing, alignment: .center, spacing: 4) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("média").font(.system(size: 9)).foregroundStyle(Color(palette.textSecondary))
                        Text(VelocityChart.format(result.averageCompleted.rounded())).font(.system(size: 10.5, weight: .semibold)).foregroundStyle(Color(palette.text))
                    }
                }
            if let sprint = selected {
                let index = result.sprints.firstIndex { $0.id == sprint.id } ?? 0
                RuleMark(x: .value("Sprint", sprint.shortName))
                    .foregroundStyle(.clear)
                    .annotation(position: index < result.sprints.count / 2 ? .trailing : .leading, alignment: .center, spacing: 16,
                                overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                        ChartTooltip(title: sprint.name, lines: [
                            .init(label: "Planeado", value: Self.format(sprint.planned), color: Color(palette.text).opacity(0.3)),
                            .init(label: "Concluído", value: Self.format(sprint.completed), color: accent),
                            .init(label: "Cumprido", value: sprint.planned > 0 ? "\(Int((sprint.completed / sprint.planned * 100).rounded()))%" : "—", color: Color(palette.textTertiary)),
                        ])
                    }
            }
        }
        .chartYScale(domain: 0...scale.top)
        .chartPlotStyle { plot in plot.padding(.trailing, 32) }   // the average's label sits past the bars
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let name = value.as(String.self) {
                        Text(name).fontWeight(name == latest?.shortName ? .semibold : .regular)
                            .foregroundStyle(name == latest?.shortName ? Color(palette.text) : Color(palette.textTertiary))
                    }
                }
                .font(.system(size: 9))
            }
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
