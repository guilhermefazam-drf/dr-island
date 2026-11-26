import SwiftUI
import Charts
import DrIslandCore

/// Bugs created rising above the line (warm) and resolved hanging below it (cool), week by week, on one scale: each
/// week's balance reads as the difference in length. Red against blue stays apart for colour-blind readers.
/// Hovering a week shows its numbers.
struct BugsChart: View {
    @Environment(\.islandPalette) private var palette
    let weeks: [BugWeek]
    @State private var hovered: Date?

    var body: some View {
        let top = ChartScale.nice(maxValue: Double(weeks.map { max($0.created, $0.resolved) }.max() ?? 0), ticks: 2).top
        let gap = top * 0.025   // a hairline of air either side of the baseline
        let selected = hovered.flatMap(nearest)
        Chart {
            ForEach(weeks) { week in
                let dimmed = selected != nil && selected?.id != week.id
                if week.created > 0 {
                    BarMark(x: .value("Semana", week.start, unit: .weekOfYear), yStart: .value("Base", gap), yEnd: .value("Criados", Double(week.created) + gap), width: .ratio(0.26))
                        .foregroundStyle(Self.createdColor(palette).opacity(dimmed ? 0.35 : 1))
                        .cornerRadius(3)
                }
                if week.resolved > 0 {
                    BarMark(x: .value("Semana", week.start, unit: .weekOfYear), yStart: .value("Base", -gap), yEnd: .value("Resolvidos", -Double(week.resolved) - gap), width: .ratio(0.26))
                        .foregroundStyle(Self.resolvedColor(palette).opacity(dimmed ? 0.35 : 1))
                        .cornerRadius(3)
                }
            }
            RuleMark(y: .value("Base", 0)).foregroundStyle(Color(palette.text).opacity(0.14)).lineStyle(StrokeStyle(lineWidth: 1))
            if let week = selected {
                RuleMark(x: .value("Semana", week.start, unit: .weekOfYear))
                    .foregroundStyle(.clear)
                    .annotation(position: week.start < midWeek ? .trailing : .leading, alignment: .center, spacing: 14,
                                overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                        ChartTooltip(title: "Semana de " + week.start.formatted(.dateTime.day().month(.abbreviated)), lines: [
                            .init(label: "Criados", value: "\(week.created)", color: Self.createdColor(palette)),
                            .init(label: "Resolvidos", value: "\(week.resolved)", color: Self.resolvedColor(palette)),
                            .init(label: "Saldo", value: (week.created > week.resolved ? "+" : "") + "\(week.created - week.resolved)", color: Color(palette.textTertiary)),
                        ])
                    }
            }
        }
        .chartYScale(domain: -(top + gap)...(top + gap))
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfYear, count: 2)) {
                AxisValueLabel(format: .dateTime.day().month(.twoDigits)).font(.system(size: 9)).foregroundStyle(Color(palette.textTertiary))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: [-top, 0, top]) { value in
                AxisValueLabel {
                    if let v = value.as(Double.self) { Text("\(Int(abs(v)))") }
                }
                .font(.system(size: 9)).foregroundStyle(Color(palette.textTertiary))
            }
        }
        .chartHover($hovered)
        .accessibilityElement()
        .accessibilityLabel("Bugs criados e resolvidos por semana, nas últimas \(weeks.count) semanas")
    }

    static func createdColor(_ palette: IslandPalette) -> Color { Color(palette.red) }
    static func resolvedColor(_ palette: IslandPalette) -> Color { Color(palette.accent) }

    private var midWeek: Date {
        guard let first = weeks.first?.start, let last = weeks.last?.start else { return Date() }
        return first.addingTimeInterval(last.timeIntervalSince(first) / 2)
    }

    /// The week whose middle is closest to the pointer.
    private func nearest(to date: Date) -> BugWeek? {
        weeks.min { abs($0.start.addingTimeInterval(3.5 * 86_400).timeIntervalSince(date)) < abs($1.start.addingTimeInterval(3.5 * 86_400).timeIntervalSince(date)) }
    }
}
