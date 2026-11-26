import AppKit
import SwiftUI
import DrIslandCore

/// Events per hour as slim columns on a hairline baseline: an hour with nothing keeps a faint stub so the day still
/// reads, the busiest hour carries its count and the current hour is labelled in full ink. Hovering a column names it.
/// Used small in the island and large in the settings.
struct HourlyColumnChart: View {
    let counts: [Int]
    let range: ClosedRange<Int>
    /// The current hour, emphasised; nil for a past day.
    var nowHour: Int?
    var height: CGFloat
    var labelStride = 3
    @Environment(\.islandPalette) private var palette

    private static let axisHeight: CGFloat = 12
    private static let valueHeight: CGFloat = 11

    var body: some View {
        let hours = Array(range)
        let values = hours.map { counts.indices.contains($0) ? counts[$0] : 0 }
        let peak = values.max() ?? 0
        let top = Double(max(peak, 3))
        let peakIndex = peak > 0 ? values.firstIndex(of: peak) : nil
        GeometryReader { geo in
            let width = geo.size.width
            let slot = width / CGFloat(max(hours.count, 1))
            let column = min(max(slot * 0.56, 3), 14)
            let baseline = geo.size.height - Self.axisHeight - 3
            let plotH = baseline - Self.valueHeight
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Color(palette.text).opacity(0.1)).frame(width: width, height: 0.5).offset(y: baseline)
                ForEach(hours.indices, id: \.self) { i in
                    let x = slot * (CGFloat(i) + 0.5)
                    let isNow = hours[i] == nowHour
                    let h = values[i] > 0 ? max(3, plotH * CGFloat(Double(values[i]) / top)) : 2
                    UnevenRoundedRectangle(topLeadingRadius: min(3, column / 2), topTrailingRadius: min(3, column / 2))
                        .fill(values[i] > 0 ? Color(palette.accent) : Color(palette.text).opacity(isNow ? 0.3 : 0.1))
                        .frame(width: column, height: h)
                        .position(x: x, y: baseline - h / 2)
                    // A wider, invisible target, so the hover does not need to land on a 4 pt column.
                    Color.clear.contentShape(Rectangle())
                        .frame(width: slot, height: baseline)
                        .position(x: x, y: baseline / 2)
                        .islandTip("\(Self.hourLabel(hours[i])): \(values[i]) \(values[i] == 1 ? "evento" : "eventos")")
                    if i == peakIndex {
                        Text("\(values[i])").font(.system(size: 9, weight: .semibold)).foregroundStyle(Color(palette.text)).monospacedDigit()
                            .position(x: x, y: baseline - h - Self.valueHeight / 2 - 1)
                    }
                }
                ForEach(labelHours(hours), id: \.self) { hour in
                    if let i = hours.firstIndex(of: hour) {
                        let isNow = hour == nowHour
                        Text(isNow ? "agora" : Self.hourLabel(hour))
                            .font(.system(size: 9, weight: isNow ? .semibold : .regular)).monospacedDigit()
                            .foregroundStyle(isNow ? Color(palette.text) : Color(palette.textTertiary))
                            .fixedSize()
                            .position(x: min(max(slot * (CGFloat(i) + 0.5), 14), width - 14), y: baseline + 3 + Self.axisHeight / 2)
                    }
                }
            }
        }
        .frame(height: height)
    }

    private static func hourLabel(_ hour: Int) -> String { hour.formatted(.number.precision(.integerLength(2))) + "h" }

    /// Always the first and the last hour, plus every `labelStride` hours between them when they do not crowd the ends.
    private func labelHours(_ hours: [Int]) -> [Int] {
        guard let first = hours.first, let last = hours.last else { return [] }
        let middle = hours.dropFirst().dropLast().filter { $0 % labelStride == 0 && $0 - first >= 2 && last - $0 >= 2 }
        return [first] + middle + (last == first ? [] : [last])
    }
}
