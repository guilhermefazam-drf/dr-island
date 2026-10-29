import AppKit
import SwiftUI
import DrIslandCore

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
