import AppKit
import SwiftUI
import DrIslandCore

/// One line that scrolls to and fro when it does not fit, instead of being cut off.
struct MarqueeText: View {
    let text: String
    var font: Font = .caption
    var color: Color = .white

    @State private var textWidth: CGFloat = 0
    @State private var boxWidth: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var overflow: CGFloat { max(0, textWidth - boxWidth) }

    var body: some View {
        // With Reduce Motion the text stays put and is truncated instead of sliding.
        if reduceMotion {
            Text(text).font(font).foregroundStyle(color).lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            sliding
        }
    }

    private var sliding: some View {
        // The invisible, truncated copy gives the box its height and a width that never exceeds the column;
        // the real text is laid out at its natural width inside it and slid along when it is longer.
        Text(text).font(font).lineLimit(1).opacity(0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(GeometryReader { geo in
                Color.clear.onAppear { boxWidth = geo.size.width }.onChange(of: geo.size.width) { _, w in boxWidth = w }
            })
            .overlay(alignment: .leading) {
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: overflow == 0)) { context in
                    Text(text).font(font).foregroundStyle(color).fixedSize()
                        .background(GeometryReader { geo in
                            Color.clear.onAppear { textWidth = geo.size.width }.onChange(of: geo.size.width) { _, w in textWidth = w }
                        })
                        .offset(x: -offset(at: context.date))
                }
            }
            .clipped()
            .id(text)
    }

    /// Wait, scroll to the end, wait, scroll back.
    private func offset(at date: Date) -> CGFloat {
        guard overflow > 0 else { return 0 }
        let travel = Double(overflow) / 28, pause = 1.6
        let total = 2 * (travel + pause)
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: total)
        if t < pause { return 0 }
        if t < pause + travel { return CGFloat((t - pause) / travel) * overflow }
        if t < 2 * pause + travel { return overflow }
        return CGFloat(1 - (t - 2 * pause - travel) / travel) * overflow
    }
}
