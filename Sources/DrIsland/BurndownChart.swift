import SwiftUI
import Charts
import DrIslandCore

/// Remaining work as a line with a soft wash under it, the ideal as a thin dashed guide, the scope as a quiet step line,
/// the days still to come shaded, «hoje» as a pill and a dashed forecast to the sprint's last day. Hovering a day shows
/// its numbers.
struct BurndownChart: View {
    @Environment(\.islandPalette) private var palette
    let result: BurndownResult
    /// The sprint's last day, so the chart spans the whole sprint and not only the days so far.
    let end: Date?
    /// What the pace so far leaves open at the end; nil once the sprint has ended.
    let forecast: Double?
    @State private var hovered: Date?

    var body: some View {
        let calendar = Calendar.current
        let points = result.points
        let first = points.first?.date ?? Date(), last = points.last
        let lastDay = max(end.map { calendar.startOfDay(for: $0) } ?? first, last?.date ?? first)
        let today = calendar.startOfDay(for: Date())
        let scale = ChartScale.nice(maxValue: points.map { max($0.scope, $0.remaining, $0.ideal) }.max() ?? 0)
        let accent = Color(palette.accent)
        let plot = Color(palette.base.first ?? palette.collar)
        let selected = hovered.flatMap(nearest)
        let future = last.map { $0.date < lastDay } ?? false
        Chart {
            if future, let last {
                RectangleMark(xStart: .value("Dia", last.date), xEnd: .value("Dia", lastDay), yStart: .value("Base", 0), yEnd: .value("Topo", scale.top))
                    .foregroundStyle(Color(palette.text).opacity(0.035))
            }
            ForEach(points, id: \.date) { point in
                AreaMark(x: .value("Dia", point.date), y: .value("Por fazer", point.remaining))
                    .foregroundStyle(LinearGradient(colors: [accent.opacity(0.24), accent.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Dia", point.date), y: .value("Âmbito", point.scope), series: .value("Série", "Âmbito"))
                    .foregroundStyle(Color(palette.textTertiary).opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .interpolationMethod(.stepEnd)
                LineMark(x: .value("Dia", point.date), y: .value("Por fazer", point.remaining), series: .value("Série", "Por fazer"))
                    .foregroundStyle(accent)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            // The ideal and the scope carry on to the last day; the ideal reaches 0 there.
            ForEach(idealLine(to: lastDay), id: \.date) { point in
                LineMark(x: .value("Dia", point.date), y: .value("Ideal", point.value), series: .value("Série", "Ideal"))
                    .foregroundStyle(Color(palette.textTertiary))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
            if future, let last {
                LineMark(x: .value("Dia", last.date), y: .value("Âmbito", last.scope), series: .value("Série", "Âmbito futuro"))
                    .foregroundStyle(Color(palette.textTertiary).opacity(0.8)).lineStyle(StrokeStyle(lineWidth: 1))
                LineMark(x: .value("Dia", lastDay), y: .value("Âmbito", last.scope), series: .value("Série", "Âmbito futuro"))
                    .foregroundStyle(Color(palette.textTertiary).opacity(0.8)).lineStyle(StrokeStyle(lineWidth: 1))
                if let forecast {
                    LineMark(x: .value("Dia", last.date), y: .value("Previsão", last.remaining), series: .value("Série", "Previsão"))
                        .foregroundStyle(accent.opacity(0.6)).lineStyle(StrokeStyle(lineWidth: 1.6, lineCap: .round, dash: [4, 3]))
                    LineMark(x: .value("Dia", lastDay), y: .value("Previsão", forecast), series: .value("Série", "Previsão"))
                        .foregroundStyle(accent.opacity(0.6)).lineStyle(StrokeStyle(lineWidth: 1.6, lineCap: .round, dash: [4, 3]))
                    PointMark(x: .value("Dia", lastDay), y: .value("Previsão", forecast))
                        .symbol { Circle().strokeBorder(accent.opacity(0.8), lineWidth: 1.5).background(Circle().fill(plot)).frame(width: 7, height: 7) }
                        .annotation(position: .trailing, spacing: 3) {
                            Text("~" + Self.format(forecast.rounded())).font(.system(size: 9)).foregroundStyle(Color(palette.textTertiary))
                        }
                }
            }
            if today >= first, today <= lastDay {
                RuleMark(x: .value("Hoje", today))
                    .foregroundStyle(Color(palette.amber).opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .annotation(position: .top, alignment: .center, spacing: 1) {
                        Text("hoje").font(.system(size: 9, weight: .semibold)).foregroundStyle(Color(palette.amber))
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Capsule().fill(Color(palette.amber).opacity(0.18)).background(Capsule().fill(plot)))
                    }
            }
            if let last, selected == nil {
                PointMark(x: .value("Dia", last.date), y: .value("Por fazer", last.remaining))
                    .symbol { dot(accent, ring: plot) }
                    .annotation(position: .topTrailing, spacing: 2) {
                        Text("\(Self.format(last.remaining))").font(.system(size: 10.5, weight: .semibold)).foregroundStyle(Color(palette.text))
                    }
            }
            if let point = selected {
                RuleMark(x: .value("Dia", point.date))
                    .foregroundStyle(Color(palette.text).opacity(0.2))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .annotation(position: point.date < midpoint(first, lastDay) ? .trailing : .leading, alignment: .center, spacing: 8,
                                overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                        ChartTooltip(title: point.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)), lines: [
                            .init(label: "Por fazer", value: Self.format(point.remaining), color: accent),
                            .init(label: "Ideal", value: Self.format(point.ideal), color: Color(palette.textTertiary)),
                            .init(label: "Âmbito", value: Self.format(point.scope), color: Color(palette.textTertiary)),
                        ])
                    }
                PointMark(x: .value("Dia", point.date), y: .value("Por fazer", point.remaining))
                    .symbol { dot(accent, ring: plot) }
            }
        }
        .chartXScale(domain: first...lastDay)
        .chartYScale(domain: 0...scale.top)
        .chartPlotStyle { plot in plot.padding(.trailing, 22).padding(.top, 10) }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) {
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

    private func dot(_ color: Color, ring: Color) -> some View {
        Circle().fill(color).frame(width: 8, height: 8).background(Circle().fill(ring).padding(-2))
    }

    /// The ideal of each day so far, then 0 on the sprint's last day.
    private func idealLine(to lastDay: Date) -> [(date: Date, value: Double)] {
        var line = result.points.map { (date: $0.date, value: $0.ideal) }
        if let last = line.last, last.date < lastDay { line.append((lastDay, 0)) }
        return line
    }

    private func midpoint(_ a: Date, _ b: Date) -> Date { a.addingTimeInterval(b.timeIntervalSince(a) / 2) }

    private func nearest(to date: Date) -> BurndownPoint? {
        result.points.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
    }

    static func format(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0...1))) }
}
