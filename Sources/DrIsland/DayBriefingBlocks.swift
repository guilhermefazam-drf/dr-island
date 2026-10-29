import AppKit
import SwiftUI
import DrIslandCore

/// One entry of the alert history as a row: tone dot, message, and a caption on the right. Opens its PR or task when it has one.
private struct EntryRow: View {
    let entry: AlertEntry
    let caption: String

    var body: some View {
        let content = HStack(spacing: 8) {
            Circle().fill(entry.tone.color).frame(width: 7, height: 7)
            Text(entry.displayMessage).font(.caption).foregroundStyle(.white.opacity(0.9)).lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 4)
            Text(caption).font(.caption2).foregroundStyle(.secondary).monospacedDigit()
        }
        .frame(height: IslandLayout.alertsRow)
        .contentShape(Rectangle())
        if let url = entry.destination {
            Button { NSWorkspace.shared.open(url) } label: { content }.buttonStyle(.plain).pointingHandCursor().islandTip("Abrir")
        } else {
            content
        }
    }
}

private func clock(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    return f.string(from: date)
}

private let linkBlue = Color(red: 0.45, green: 0.68, blue: 1.0)

// MARK: - Gráfico por hora

/// Events per hour as a smooth line with a soft area, dots on the hours that had something, and hour labels underneath.
/// Used small in the island and large in the settings.
struct HourlyLineChart: View {
    let counts: [Int]
    let range: ClosedRange<Int>
    /// The current hour, drawn as the green end of the line; nil for a past day.
    var nowHour: Int?
    var height: CGFloat
    var labelStride = 3

    private static let axisHeight: CGFloat = 12

    var body: some View {
        let hours = Array(range)
        let values = hours.map { Double(counts.indices.contains($0) ? counts[$0] : 0) }
        let top = max(values.max() ?? 0, 3)
        GeometryReader { geo in
            let plotH = geo.size.height - Self.axisHeight - 4
            let width = geo.size.width
            let points: [CGPoint] = hours.indices.map { i in
                CGPoint(x: hours.count > 1 ? width * CGFloat(i) / CGFloat(hours.count - 1) : width / 2,
                        y: 3 + (plotH - 6) * (1 - CGFloat(values[i] / top)))
            }
            ZStack(alignment: .topLeading) {
                Path { p in p.move(to: CGPoint(x: 0, y: plotH)); p.addLine(to: CGPoint(x: width, y: plotH)) }
                    .stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                Self.area(points, base: plotH).fill(LinearGradient(colors: [Brand.blue.opacity(0.35), Brand.blue.opacity(0)], startPoint: .top, endPoint: .bottom))
                Self.line(points).stroke(Brand.blue, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                ForEach(hours.indices, id: \.self) { i in
                    let isNow = hours[i] == nowHour
                    if values[i] > 0 || isNow {
                        Circle().fill(isNow ? Brand.green : Brand.blue).frame(width: isNow ? 6 : 4, height: isNow ? 6 : 4)
                            .position(points[i])
                    }
                }
                ForEach(labelHours(hours), id: \.self) { hour in
                    if let i = hours.firstIndex(of: hour) {
                        Text(hour.formatted(.number.precision(.integerLength(2))) + "h").font(.system(size: 9)).foregroundStyle(.secondary).monospacedDigit()
                            .position(x: min(max(points[i].x, 10), width - 10), y: plotH + 4 + Self.axisHeight / 2)
                    }
                }
            }
        }
        .frame(height: height)
    }

    /// Always the first and the last hour, plus every `labelStride` hours between them when they do not crowd the ends.
    private func labelHours(_ hours: [Int]) -> [Int] {
        guard let first = hours.first, let last = hours.last else { return [] }
        let middle = hours.dropFirst().dropLast().filter { $0 % labelStride == 0 && $0 - first >= 2 && last - $0 >= 2 }
        return [first] + middle + (last == first ? [] : [last])
    }

    private static func line(_ pts: [CGPoint]) -> Path {
        Path { p in
            guard let first = pts.first else { return }
            p.move(to: first)
            for (a, b) in zip(pts, pts.dropFirst()) {
                let mid = (a.x + b.x) / 2
                p.addCurve(to: b, control1: CGPoint(x: mid, y: a.y), control2: CGPoint(x: mid, y: b.y))
            }
        }
    }

    private static func area(_ pts: [CGPoint], base: CGFloat) -> Path {
        var p = line(pts)
        guard let first = pts.first, let last = pts.last else { return p }
        p.addLine(to: CGPoint(x: last.x, y: base))
        p.addLine(to: CGPoint(x: first.x, y: base))
        p.closeSubpath()
        return p
    }
}

// MARK: - Linha do tempo

/// Today as a line chart of events per hour. «resumo» opens the briefing; «detalhes» opens the settings page with every event.
struct TimelineBlock: View {
    let counts: [Int]
    let showBriefing: () -> Void
    let openDetails: () -> Void

    static let chartHeight: CGFloat = 54
    static var contentHeight: CGFloat { IslandLayout.alertsHeader + 6 + chartHeight }

    var body: some View {
        let total = counts.reduce(0, +)
        let hour = Calendar.current.component(.hour, from: Date())
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Label(total == 0 ? "Hoje" : "Hoje · \(total) \(total == 1 ? "evento" : "eventos")", systemImage: "chart.xyaxis.line")
                    .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                Spacer()
                Button(action: showBriefing) { Text("resumo").font(.caption2).foregroundStyle(linkBlue) }
                    .buttonStyle(.plain).pointingHandCursor()
                    .islandTip("O que mudou desde a última vez que viste a ilha")
                Button(action: openDetails) { Text("detalhes").font(.caption2).foregroundStyle(linkBlue) }
                    .buttonStyle(.plain).pointingHandCursor()
                    .islandTip("Todos os eventos do dia, nas definições")
            }
            .frame(height: IslandLayout.alertsHeader)
            HourlyLineChart(counts: counts, range: DayBriefing.hourRange(counts, endHour: hour), nowHour: hour, height: Self.chartHeight)
                .overlay {
                    if total == 0 {
                        Text("Ainda sem eventos hoje").font(.caption2).foregroundStyle(.secondary).padding(.bottom, 14)
                    }
                }
        }
        .frame(height: Self.contentHeight, alignment: .top)
        .blockCard()
    }
}

// MARK: - Resumo do dia

/// «O que mudou desde…»: the entries newer than the last look, with a count per source and a button to dismiss it.
struct BriefingBlock: View {
    let entries: [AlertEntry]
    let since: Date
    let dismiss: () -> Void

    static let maxRows = 5
    static let summaryHeight: CGFloat = 16

    static func contentHeight(rows: Int) -> CGFloat {
        IslandLayout.alertsHeader + 6 + summaryHeight + 4 + CGFloat(max(rows, 1)) * IslandLayout.alertsRow
    }

    var body: some View {
        let shown = Array(entries.prefix(Self.maxRows))
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(DayBriefing.sinceLabel(since, now: Date()), systemImage: "sunrise").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                Spacer()
                Button(action: dismiss) { Text("ok").font(.caption2.weight(.semibold)).foregroundStyle(linkBlue) }
                    .buttonStyle(.plain).pointingHandCursor()
                    .islandTip("Marcar como visto")
            }
            .frame(height: IslandLayout.alertsHeader)
            Text(entries.isEmpty ? "Sem novidades" : DayBriefing.summary(entries) + (entries.count > Self.maxRows ? " · \(entries.count - Self.maxRows) mais" : ""))
                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                .frame(height: Self.summaryHeight, alignment: .leading)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(shown) { EntryRow(entry: $0, caption: clock($0.date)) }
            }
        }
        .frame(height: Self.contentHeight(rows: shown.count), alignment: .top)
        .blockCard()
    }
}
