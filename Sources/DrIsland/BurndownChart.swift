import SwiftUI
import Charts
import DrIslandCore

/// Remaining work as a line with a soft wash under it, the ideal as a thin dashed guide, the scope as a quiet step
/// line and a hairline for today. Hovering a day shows its numbers.
struct BurndownChart: View {
    @Environment(\.islandPalette) private var palette
    let result: BurndownResult
    @State private var hovered: Date?

    var body: some View {
        let today = Calendar.current.startOfDay(for: Date())
        let first = result.points.first?.date, last = result.points.last?.date
        let scale = ChartScale.nice(maxValue: result.points.map { max($0.scope, $0.remaining, $0.ideal) }.max() ?? 0)
        let accent = Color(palette.accent)
        let selected = hovered.flatMap(nearest)
        Chart {
            ForEach(result.points, id: \.date) { point in
                AreaMark(x: .value("Dia", point.date), y: .value("Por fazer", point.remaining))
                    .foregroundStyle(LinearGradient(colors: [accent.opacity(0.22), accent.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Dia", point.date), y: .value("Âmbito", point.scope), series: .value("Série", "Âmbito"))
                    .foregroundStyle(Color(palette.neutral).opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .interpolationMethod(.stepEnd)
                LineMark(x: .value("Dia", point.date), y: .value("Ideal", point.ideal), series: .value("Série", "Ideal"))
                    .foregroundStyle(Color(palette.textTertiary))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                LineMark(x: .value("Dia", point.date), y: .value("Por fazer", point.remaining), series: .value("Série", "Por fazer"))
                    .foregroundStyle(accent)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            if let first, let last, today >= first, today <= last {
                RuleMark(x: .value("Hoje", today))
                    .foregroundStyle(Color(palette.amber).opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .annotation(position: .top, alignment: .center, spacing: 2) {
                        Text("hoje").font(.system(size: 9, weight: .medium)).foregroundStyle(Color(palette.textSecondary))
                    }
            }
            // The latest reading: a dot ringed in the card's colour, with its value beside it.
            if let end = result.points.last, selected == nil {
                PointMark(x: .value("Dia", end.date), y: .value("Por fazer", end.remaining))
                    .symbol { endDot(accent) }
                    .annotation(position: .topTrailing, spacing: 2) {
                        Text(Self.format(end.remaining)).font(.system(size: 10, weight: .semibold)).foregroundStyle(Color(palette.text))
                    }
            }
            if let point = selected {
                RuleMark(x: .value("Dia", point.date))
                    .foregroundStyle(Color(palette.text).opacity(0.18))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .annotation(position: .top, spacing: 0, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                        ChartTooltip(title: point.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)), lines: [
                            .init(label: "Por fazer", value: Self.format(point.remaining), color: accent),
                            .init(label: "Ideal", value: Self.format(point.ideal), color: Color(palette.textTertiary)),
                            .init(label: "Âmbito", value: Self.format(point.scope), color: Color(palette.neutral)),
                        ])
                    }
                PointMark(x: .value("Dia", point.date), y: .value("Por fazer", point.remaining))
                    .symbol { endDot(accent) }
            }
        }
        .chartYScale(domain: 0...scale.top)
        .chartPlotStyle { plot in plot.padding(.trailing, 18) }   // room for the last value and date label
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 3)) {
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
        .accessibilityLabel("Burndown da sprint: \(BurndownSummary.doneText(result)), \(BurndownSummary.flaggedText(result))")
    }

    private func endDot(_ color: Color) -> some View {
        Circle().fill(color).frame(width: 8, height: 8)
            .background(Circle().fill(Color(palette.base.first ?? palette.collar)).padding(-2))
    }

    private func nearest(to date: Date) -> BurndownPoint? {
        result.points.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
    }

    static func format(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0...1))) }
}
