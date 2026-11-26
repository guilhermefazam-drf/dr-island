import Foundation

/// How the sprint is going against its plan, for the «Gestão» numbers and the burndown's forecast: what is done,
/// how far the remaining work is from the ideal line today, and what will be left at the end at the pace so far.
public struct SprintPace: Equatable, Sendable {
    public var done: Double
    public var scope: Double
    /// Remaining minus the ideal for today: above 0 the sprint is behind, below 0 ahead.
    public var behind: Double
    /// Work still open at the sprint's last day if the pace so far holds; nil once the sprint has ended.
    public var forecastLeft: Double?
    /// Working days after today until the end (0 on the last day and after it).
    public var workdaysLeft: Int
    /// Share of the sprint's working days already gone, 0…1.
    public var elapsedShare: Double
    /// What came into the sprint after it started (never negative).
    public var scopeAdded: Double

    public var doneShare: Double { scope > 0 ? done / scope : 0 }

    public init(done: Double, scope: Double, behind: Double, forecastLeft: Double?, workdaysLeft: Int, elapsedShare: Double, scopeAdded: Double) {
        self.done = done; self.scope = scope; self.behind = behind; self.forecastLeft = forecastLeft
        self.workdaysLeft = workdaysLeft; self.elapsedShare = elapsedShare; self.scopeAdded = scopeAdded
    }

    public static func compute(_ result: BurndownResult, start: Date?, end: Date?, closed: Bool, now: Date, calendar: Calendar) -> SprintPace? {
        guard let last = result.points.last else { return nil }
        let done = max(last.scope - last.remaining, 0)
        let startDay = calendar.startOfDay(for: start ?? result.points.first?.date ?? now)
        let endDay = calendar.startOfDay(for: end ?? now)
        let today = calendar.startOfDay(for: now)
        let total = workdays(from: startDay, through: endDay, calendar)
        let elapsed = workdays(from: startDay, through: min(today, endDay), calendar)
        let left = today >= endDay ? 0 : workdays(from: calendar.date(byAdding: .day, value: 1, to: today) ?? today, through: endDay, calendar)
        let pace = elapsed > 0 ? done / Double(elapsed) : 0
        let ended = closed || today > endDay
        return SprintPace(
            done: done, scope: last.scope, behind: last.remaining - last.ideal,
            forecastLeft: ended ? nil : max(last.remaining - pace * Double(left), 0),
            workdaysLeft: left,
            elapsedShare: total > 0 ? min(Double(elapsed) / Double(total), 1) : 0,
            scopeAdded: max(last.scope - result.plannedScope, 0))
    }

    /// Monday-to-Friday days from `from` through `through`, both included.
    static func workdays(from: Date, through: Date, _ calendar: Calendar) -> Int {
        var count = 0, day = from
        while day <= through {
            if SprintIssueState.isWorkday(day, calendar) { count += 1 }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return count
    }
}
