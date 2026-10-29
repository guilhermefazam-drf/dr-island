import SwiftUI
import DrIslandCore

/// Confetti that bursts from under the notch and falls with a little gravity whenever `tick` changes.
struct ConfettiBurst: View {
    let tick: Int
    @State private var progress: CGFloat = 0

    private struct Piece: Identifiable {
        let id: Int
        let angle: Double, distance: CGFloat, spin: Double, size: CGSize, color: Color
    }

    /// Fixed, so the burst looks the same every time and needs no randomness at draw time.
    private static let pieces: [Piece] = {
        let colors = [Brand.green, Brand.amber, Brand.blue, Brand.red, Color.white, Color(red: 0.8, green: 0.5, blue: 1)]
        return (0..<36).map { i in
            let t = Double(i)
            return Piece(id: i,
                         angle: .pi * (0.08 + 0.84 * (t.truncatingRemainder(dividingBy: 12) / 11)),   // fan below the notch
                         distance: 70 + CGFloat((i * 37) % 90),
                         spin: 180 + Double((i * 53) % 360),
                         size: CGSize(width: 4 + CGFloat(i % 3) * 2, height: 7 + CGFloat(i % 2) * 3),
                         color: colors[i % colors.count])
        }
    }()

    private static let duration: TimeInterval = 2.2
    @State private var startedAt: Date?

    var body: some View {
        // Driven by the clock instead of an animated value: opacity and gravity are not linear in `progress`.
        TimelineView(.animation(paused: startedAt == nil)) { context in
            let t = startedAt.map { context.date.timeIntervalSince($0) / Self.duration } ?? 1
            ZStack {
                if t >= 0 && t < 1 {
                    let progress = CGFloat(1 - pow(1 - t, 3))   // ease-out for the burst
                    ForEach(Self.pieces) { p in
                        Rectangle()
                            .fill(p.color)
                            .frame(width: p.size.width, height: p.size.height)
                            .rotationEffect(.degrees(p.spin * t))
                            .offset(x: CGFloat(cos(p.angle)) * p.distance * 1.6 * progress,
                                    y: CGFloat(sin(p.angle)) * p.distance * 0.5 * progress + 90 * CGFloat(t * t))
                            .opacity(min(1, (1 - t) * 3))
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .onChange(of: tick) { _, _ in
            let now = Date()
            startedAt = now
            Task {
                try? await Task.sleep(for: .seconds(Self.duration + 0.1))
                if startedAt == now { startedAt = nil }
            }
        }
    }
}
