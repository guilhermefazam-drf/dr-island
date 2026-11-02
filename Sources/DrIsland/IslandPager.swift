import SwiftUI

/// Two pages side by side that slide with `progress` (0 = first, 1 = second). With Reduce Motion they cross-fade instead.
struct IslandPager<First: View, Second: View>: View {
    let progress: Double
    let width: CGFloat
    @ViewBuilder var first: First
    @ViewBuilder var second: Second
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            ZStack(alignment: .top) {
                first.opacity(1 - progress).allowsHitTesting(progress < 0.5)
                second.opacity(progress).allowsHitTesting(progress >= 0.5)
            }
            .frame(width: width, alignment: .top)
        } else {
            HStack(alignment: .top, spacing: 0) {
                first.frame(width: width).allowsHitTesting(progress < 0.5)
                second.frame(width: width).allowsHitTesting(progress >= 0.5)
            }
            .offset(x: -progress * width)
            .frame(width: width, alignment: .leading)
            .clipped()
        }
    }
}
