import Foundation

/// Splits the weekly window into its 5 workdays (20% each) so the weekly gauge reads as a daily limit.
/// Today's share is earned progressively while working: 8 working hours from the configured start, with a
/// 1 hour lunch break after the first 4 (09:00 start → 09:00–13:00, lunch, 14:00–18:00). The allowance is what
/// a steady pace would have used by now. Unused budget from earlier workdays carries over; weekends add none.
public enum WeeklyPace {
    public static let workdays = 5
    public static let defaultWorkStartMinute = 9 * 60
    /// Working minutes in a day, before and after lunch.
    public static let morningMinutes = 4 * 60
    public static let afternoonMinutes = 4 * 60
    public static let lunchMinutes = 60
    public static let workMinutes = morningMinutes + afternoonMinutes

    /// When the workday ends on the clock (start + work + lunch), in minutes since midnight.
    public static func workEndMinute(start: Int) -> Int { start + workMinutes + lunchMinutes }

    /// Share of one workday's budget earned at `now` (0 before the start, frozen during lunch, 1 after the end).
    public static func dayProgress(at now: Date, workStartMinute: Int = defaultWorkStartMinute, calendar: Calendar = .current) -> Double {
        let startOfDay = calendar.startOfDay(for: now)
        let elapsed = now.timeIntervalSince(startOfDay) / 60 - Double(workStartMinute)
        let worked: Double
        if elapsed <= Double(morningMinutes) {
            worked = elapsed
        } else if elapsed <= Double(morningMinutes + lunchMinutes) {
            worked = Double(morningMinutes)
        } else {
            worked = elapsed - Double(lunchMinutes)
        }
        return min(max(worked / Double(workMinutes), 0), 1)
    }

    /// Workdays (fractional) earned so far in the 7-day window ending at `resetsAt`: finished workdays count
    /// fully, today counts by how much of its working time has passed. 0…5.
    public static func elapsedWorkdays(resetsAt: Date, now: Date = Date(), workStartMinute: Int = defaultWorkStartMinute,
                                       calendar: Calendar = .current) -> Double {
        guard let windowStart = calendar.date(byAdding: .day, value: -7, to: resetsAt) else { return Double(workdays) }
        var day = calendar.startOfDay(for: windowStart)
        let today = calendar.startOfDay(for: now)
        var total = 0.0
        while day <= today, total < Double(workdays) {
            if !calendar.isDateInWeekend(day) {
                total += day < today ? 1 : dayProgress(at: now, workStartMinute: workStartMinute, calendar: calendar)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return min(total, Double(workdays))
    }

    /// The share of the week (0…1) that may be used by `now`; never below one working hour's share, so the
    /// start of the week (before the start time or on a weekend) does not divide by zero.
    public static func allowance(resetsAt: Date, now: Date = Date(), workStartMinute: Int = defaultWorkStartMinute,
                                 calendar: Calendar = .current) -> Double {
        let floor = 1 / (Double(workdays) * Double(workMinutes) / 60)
        return max(elapsedWorkdays(resetsAt: resetsAt, now: now, workStartMinute: workStartMinute, calendar: calendar) / Double(workdays), floor)
    }

    /// Weekly usage measured against the allowance so far, for colouring with the same amber/red limits as the session.
    /// Without a reset date there is no window to split, so it falls back to the plain weekly fraction.
    public static func fraction(weekly: Double, resetsAt: Date?, now: Date = Date(), workStartMinute: Int = defaultWorkStartMinute,
                                calendar: Calendar = .current) -> Double {
        guard let resetsAt else { return weekly }
        return weekly / allowance(resetsAt: resetsAt, now: now, workStartMinute: workStartMinute, calendar: calendar)
    }
}
