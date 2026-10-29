import Foundation

/// Splits the weekly window into its 5 workdays (20% each) so the weekly gauge reads as a daily limit.
/// Unused budget from earlier workdays carries over; weekends add no budget.
public enum WeeklyPace {
    public static let workdays = 5

    /// Workdays of the 7-day window ending at `resetsAt` that have started by `now` (today included), 0…5.
    public static func elapsedWorkdays(resetsAt: Date, now: Date = Date(), calendar: Calendar = .current) -> Int {
        guard let windowStart = calendar.date(byAdding: .day, value: -7, to: resetsAt) else { return workdays }
        var day = calendar.startOfDay(for: windowStart)
        let today = calendar.startOfDay(for: now)
        var count = 0
        while day <= today, count < workdays {
            if !calendar.isDateInWeekend(day) { count += 1 }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return count
    }

    /// The share of the week (0…1) that may be used by the end of today; at least one workday's share.
    public static func allowance(resetsAt: Date, now: Date = Date(), calendar: Calendar = .current) -> Double {
        Double(max(elapsedWorkdays(resetsAt: resetsAt, now: now, calendar: calendar), 1)) / Double(workdays)
    }

    /// Weekly usage measured against today's allowance, for colouring with the same amber/red limits as the session.
    /// Without a reset date there is no window to split, so it falls back to the plain weekly fraction.
    public static func fraction(weekly: Double, resetsAt: Date?, now: Date = Date(), calendar: Calendar = .current) -> Double {
        guard let resetsAt else { return weekly }
        return weekly / allowance(resetsAt: resetsAt, now: now, calendar: calendar)
    }
}
