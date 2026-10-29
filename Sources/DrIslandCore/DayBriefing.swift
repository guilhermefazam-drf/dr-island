import Foundation

/// The day as a line of events («linha do tempo») and the digest of what changed since the user last looked («briefing»).
/// Both are views over the `AlertLog`; nothing here stores anything.
public enum DayBriefing {
    /// The earliest hour of the day the briefing opens by itself, so a late-night wake-up does not count as the morning.
    public static let autoFromHour = 5

    /// What happened today, oldest first, so it reads like a day.
    public static func timeline(_ entries: [AlertEntry], now: Date, calendar: Calendar = .current) -> [AlertEntry] {
        entries.filter { calendar.isDate($0.date, inSameDayAs: now) }.sorted { $0.date < $1.date }
    }

    /// How many entries fell in each hour (0–23) of `day`.
    public static func hourly(_ entries: [AlertEntry], day: Date, calendar: Calendar = .current) -> [Int] {
        var counts = Array(repeating: 0, count: 24)
        for entry in entries where calendar.isDate(entry.date, inSameDayAs: day) {
            counts[calendar.component(.hour, from: entry.date)] += 1
        }
        return counts
    }

    /// The hour with most entries (the earliest on a tie), or nil when the day is empty.
    public static func peakHour(_ counts: [Int]) -> Int? {
        guard let top = counts.max(), top > 0 else { return nil }
        return counts.firstIndex(of: top)
    }

    /// The hours a chart of `counts` should span: from the first activity (or `minStart`, whichever is earlier) up to `endHour`
    /// (the current hour today, 23 for a past day), never narrower than `minSpan` hours.
    public static func hourRange(_ counts: [Int], endHour: Int, minStart: Int = 8, minSpan: Int = 6) -> ClosedRange<Int> {
        let end = min(max(endHour, 0), 23)
        let first = counts.firstIndex { $0 > 0 } ?? minStart
        var start = min(first, minStart, end)
        if end - start < minSpan { start = max(0, end - minSpan) }
        if end - start < minSpan { return start...min(23, start + minSpan) }
        return start...end
    }

    /// Entries newer than `since`, newest first.
    public static func entries(_ entries: [AlertEntry], since: Date) -> [AlertEntry] {
        entries.filter { $0.date > since }.sorted { $0.date > $1.date }
    }

    /// "3 PRs · 2 Jira": how many entries each source has, biggest first; empty when there are none.
    public static func summary(_ entries: [AlertEntry]) -> String {
        let counts = AlertEntry.Source.allCases.map { source in (source, entries.filter { $0.source == source }.count) }
        return counts.filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .map { "\($0.1) \($0.0.title)" }
            .joined(separator: " · ")
    }

    /// The briefing opens by itself at most once per calendar day, from `autoFromHour`, and only when something happened.
    public static func shouldAutoShow(lastShown: Date?, pending: Int, now: Date, calendar: Calendar = .current) -> Bool {
        guard pending > 0, calendar.component(.hour, from: now) >= autoFromHour else { return false }
        guard let lastShown else { return true }
        return !calendar.isDate(lastShown, inSameDayAs: now)
    }

    /// "Desde ontem · 18:12", "Desde as 09:30", or the day for older ones.
    public static func sinceLabel(_ since: Date, now: Date, calendar: Calendar = .current) -> String {
        let time = since.formatted(.dateTime.hour().minute().locale(Locale(identifier: "pt_PT")))
        if calendar.isDate(since, inSameDayAs: now) { return "Desde as \(time)" }
        // Relative to `now`, not the wall clock (`isDateInYesterday` would ignore it).
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(since, inSameDayAs: yesterday) {
            return "Desde ontem · \(time)"
        }
        let day = since.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "pt_PT")))
        return "Desde \(day) · \(time)"
    }
}
