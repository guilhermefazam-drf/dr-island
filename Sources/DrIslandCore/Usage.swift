import Foundation

public struct UsageWindow: Equatable, Sendable {
    /// Percentage used, 0–100, as reported by the API.
    public let utilization: Double
    public let resetsAt: Date?

    public init(utilization: Double, resetsAt: Date?) {
        self.utilization = utilization
        self.resetsAt = resetsAt
    }

    public var fraction: Double { min(max(utilization / 100, 0), 1) }
}

public struct Usage: Equatable, Sendable {
    /// The rolling 5-hour session window.
    public let session: UsageWindow?
    public let weekly: UsageWindow?

    public init(session: UsageWindow?, weekly: UsageWindow?) {
        self.session = session
        self.weekly = weekly
    }
}

public enum UsageParser {
    public enum ParseError: Error { case invalidJSON }

    public static func parse(_ data: Data) throws -> Usage {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ParseError.invalidJSON
        }
        return Usage(session: window(root["five_hour"]), weekly: window(root["seven_day"]))
    }

    private static func window(_ value: Any?) -> UsageWindow? {
        guard let dict = value as? [String: Any],
              let utilization = (dict["utilization"] as? NSNumber)?.doubleValue else { return nil }
        let resetsAt = (dict["resets_at"] as? String).flatMap(parseDate)
        return UsageWindow(utilization: utilization, resetsAt: resetsAt)
    }

    /// Handles timestamps like `2026-10-17T14:50:00.188549+00:00` (6 fractional digits),
    /// which `ISO8601DateFormatter` only accepts when trimmed to milliseconds.
    static func parseDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        let trimmed = string.replacingOccurrences(of: #"(\.\d{3})\d+"#, with: "$1", options: .regularExpression)
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: trimmed) { return date }
        let noFraction = string.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression)
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: noFraction)
    }
}

public enum UsageLevel: Equatable, Sendable {
    case normal, warning, critical

    /// `amber` and `red` are percentages (0–100); `red` is never lower than `amber`.
    public static func level(forFraction fraction: Double, amber: Double, red: Double) -> UsageLevel {
        let percent = fraction * 100
        if percent >= max(red, amber) { return .critical }
        if percent >= amber { return .warning }
        return .normal
    }
}

public enum RemainingTime {
    public static func string(until date: Date, now: Date = Date()) -> String {
        let seconds = Int(date.timeIntervalSince(now))
        if seconds <= 0 { return "agora" }
        let minutes = (seconds + 59) / 60
        if minutes >= 24 * 60 {
            let days = minutes / (24 * 60)
            let hours = (minutes % (24 * 60)) / 60
            return hours == 0 ? "\(days)d" : "\(days)d \(hours)h"
        }
        if minutes >= 60 { return "\(minutes / 60)h \((minutes % 60).formatted(.number.precision(.integerLength(2))))m" }
        return "\(minutes)m"
    }
}
