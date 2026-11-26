import SwiftUI
import Charts
import DrIslandCore

/// Bugs created (warm) and resolved (cool), week by week, as slim paired columns. Red against blue stays apart for
/// colour-blind readers, which red against green does not. Hovering a week shows its numbers.
struct BugsChart: View {
    @Environment(\.islandPalette) private var palette
    let weeks: [BugWeek]
    @State private var hovered: Date?

    var body: some View {
        let scale = ChartScale.nice(maxValue: Double(weeks.map { max($0.created, $0.resolved) }.max() ?? 0))
        let selected = hovered.flatMap(nearest)
        Chart {
            ForEach(weeks) { week in
                let dimmed = selected != nil && selected?.id != week.id
                BarMark(x: .value("Semana", week.start, unit: .weekOfYear), y: .value("Criados", week.created), width: .fixed(7))
                    .foregroundStyle(Self.createdColor(palette).opacity(dimmed ? 0.4 : 1))
                    .cornerRadius(3)
                    .position(by: .value("Tipo", "Criados"), span: .fixed(16))
                BarMark(x: .value("Semana", week.start, unit: .weekOfYear), y: .value("Resolvidos", week.resolved), width: .fixed(7))
                    .foregroundStyle(Self.resolvedColor(palette).opacity(dimmed ? 0.4 : 1))
                    .cornerRadius(3)
                    .position(by: .value("Tipo", "Resolvidos"), span: .fixed(16))
            }
            if let week = selected {
                RuleMark(x: .value("Semana", week.start, unit: .weekOfYear))
                    .foregroundStyle(.clear)
                    .annotation(position: .top, spacing: 0, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                        ChartTooltip(title: "Semana de " + week.start.formatted(.dateTime.day().month(.abbreviated)), lines: [
                            .init(label: "Criados", value: "\(week.created)", color: Self.createdColor(palette)),
                            .init(label: "Resolvidos", value: "\(week.resolved)", color: Self.resolvedColor(palette)),
                        ])
                    }
            }
        }
        .chartYScale(domain: 0...scale.top)
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfYear, count: 2)) {
                AxisValueLabel(format: .dateTime.day().month(.twoDigits)).font(.system(size: 9)).foregroundStyle(Color(palette.textTertiary))
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
        .accessibilityLabel("Bugs criados e resolvidos por semana, nas últimas \(weeks.count) semanas")
    }

    static func createdColor(_ palette: IslandPalette) -> Color { Color(palette.red) }
    static func resolvedColor(_ palette: IslandPalette) -> Color { Color(palette.accent) }

    /// The week whose middle is closest to the pointer.
    private func nearest(to date: Date) -> BugWeek? {
        weeks.min { abs($0.start.addingTimeInterval(3.5 * 86_400).timeIntervalSince(date)) < abs($1.start.addingTimeInterval(3.5 * 86_400).timeIntervalSince(date)) }
    }
}
