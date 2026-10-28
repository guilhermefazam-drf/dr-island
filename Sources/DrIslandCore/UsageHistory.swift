import Foundation

/// The highest usage seen on one calendar day, kept locally to draw a small history chart.
public struct DayUsage: Codable, Equatable, Identifiable, Sendable {
    public var id: String { day }
    public let day: String            // "yyyy-MM-dd" in the user's calendar
    public var sessionPeak: Double    // 0…1, highest 5h-session reading of the day
    public var weeklyPeak: Double?    // 0…1, highest weekly reading of the day

    public init(day: String, sessionPeak: Double, weeklyPeak: Double? = nil) {
        self.day = day; self.sessionPeak = sessionPeak; self.weeklyPeak = weeklyPeak
    }
}

public enum UsageHistory {
    public static let keepDays = 60

    public static func key(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Folds one real reading into today's entry (peaks only go up during a day) and drops entries older than `keepDays`.
    public static func recording(session: Double, weekly: Double?, into list: [DayUsage], now: Date = Date(), calendar: Calendar = .current) -> [DayUsage] {
        let today = key(for: now, calendar: calendar)
        var result = list
        if let index = result.firstIndex(where: { $0.day == today }) {
            result[index].sessionPeak = max(result[index].sessionPeak, session)
            if let weekly { result[index].weeklyPeak = max(result[index].weeklyPeak ?? 0, weekly) }
        } else {
            result.append(DayUsage(day: today, sessionPeak: session, weeklyPeak: weekly))
        }
        return Array(result.sorted { $0.day < $1.day }.suffix(keepDays))
    }

    /// The last `count` days ending today, oldest first; days without readings are nil.
    public static func lastDays(_ count: Int, from list: [DayUsage], now: Date = Date(), calendar: Calendar = .current) -> [(date: Date, usage: DayUsage?)] {
        let byDay = Dictionary(list.map { ($0.day, $0) }, uniquingKeysWith: { first, _ in first })
        return (0..<count).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: now).map { ($0, byDay[key(for: $0, calendar: calendar)]) }
        }
    }

    public static func decode(_ json: String) -> [DayUsage] {
        json.data(using: .utf8).flatMap { try? JSONDecoder().decode([DayUsage].self, from: $0) } ?? []
    }

    public static func encode(_ list: [DayUsage]) -> String {
        (try? JSONEncoder().encode(list)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }
}
