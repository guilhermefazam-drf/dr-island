import Foundation

/// A value axis with round ticks: the top is the first round step above the data, so the plot is not mostly empty
/// (33 points draw on 0–40, not on 0–50).
public struct ChartScale: Equatable, Sendable {
    public var top: Double
    public var step: Double

    public var ticks: [Double] { stride(from: 0, through: top + step / 2, by: step).map { $0 } }

    /// Steps of 1, 2 or 5 × 10ⁿ (never fractional: counts and points need none), with a little headroom over
    /// `maxValue`: the lowest top reachable in 2 to `ticks` + 1 steps wins, and on a tie the bigger step (fewer labels).
    public static func nice(maxValue: Double, ticks: Int = 3, headroom: Double = 0.05) -> ChartScale {
        let target = max(maxValue, 0) * (1 + headroom)
        guard target > 0 else { return ChartScale(top: Double(max(ticks, 1)), step: 1) }
        let magnitude = pow(10, floor(log10(target / Double(max(ticks, 1)))))
        let candidates = [0.1, 1, 10].flatMap { scale in [1.0, 2, 5].map { max($0 * magnitude * scale, 1) } }
        let scales = Set(candidates).map { step in ChartScale(top: ceil(target / step) * step, step: step) }
        let fitting = scales.filter { (2...(ticks + 1)).contains(Int(($0.top / $0.step).rounded())) }
        let pool = fitting.isEmpty ? scales : fitting
        return pool.min { $0.top != $1.top ? $0.top < $1.top : $0.step > $1.step }!
    }
}
