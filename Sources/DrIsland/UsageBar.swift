import AppKit
import SwiftUI
import DrIslandCore

/// A progress bar with optional tick marks (for the amber and red limits, or the weekly workdays)
/// and an optional brighter marker (today's weekly allowance).
struct UsageBar: View {
    let fraction: Double
    let color: Color
    var height: CGFloat = 6
    var ticks: [Double] = []
    var marker: Double?

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                Capsule().fill(color).frame(width: max(geo.size.width * min(max(fraction, 0), 1), height))
                    .animation(.easeOut(duration: 0.5), value: fraction)
                ForEach(ticks, id: \.self) { tick in
                    Rectangle().fill(Color.black.opacity(0.55)).frame(width: 1.5, height: height)
                        .offset(x: geo.size.width * tick - 0.75)
                }
                if let marker, marker < 1 {
                    Rectangle().fill(Color.white.opacity(0.9)).frame(width: 1.5, height: height)
                        .offset(x: geo.size.width * marker - 0.75)
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: height)
    }
}
