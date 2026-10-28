import Foundation

/// A reading of a usage window at a point in time, used for the forecast.
public struct UsageSample: Equatable, Sendable {
    public let date: Date
    public let fraction: Double
    public init(date: Date, fraction: Double) { self.date = date; self.fraction = fraction }
}

public enum UsageAlerts {
    // MARK: Forecast

    /// When the window will hit 100% at the current pace, but only if that happens before it resets.
    /// Uses the last hour of readings; needs at least 10 minutes of history and real growth.
    public static func exhaustion(samples: [UsageSample], resetsAt: Date?, now: Date = Date()) -> Date? {
        guard let resetsAt, let last = samples.last, last.fraction < 1 else { return nil }
        let recent = samples.filter { now.timeIntervalSince($0.date) <= 3600 }
        guard let first = recent.first else { return nil }
        let span = last.date.timeIntervalSince(first.date)
        let growth = last.fraction - first.fraction
        guard span >= 600, growth >= 0.01 else { return nil }
        let eta = last.date.addingTimeInterval((1 - last.fraction) / (growth / span))
        return eta > now && eta < resetsAt ? eta : nil
    }
}
