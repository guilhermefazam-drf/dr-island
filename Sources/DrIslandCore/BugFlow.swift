import Foundation

/// Bugs created against bugs resolved, week by week. Pure.
public enum BugFlow {
    public static let defaultWeeks = 8

    public static func compute(_ bugs: [BugRecord], openNow: Int, openIsCapped: Bool, now: Date, calendar: Calendar, weeks: Int = defaultWeeks) -> BugResult {
        var calendar = calendar
        calendar.firstWeekday = 2   // weeks start on Monday
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)
        let starts = (0..<max(weeks, 1)).reversed().compactMap { calendar.date(byAdding: .weekOfYear, value: -$0, to: thisWeek) }

        func weekIndex(_ date: Date) -> Int? {
            starts.lastIndex { $0 <= date }.flatMap { date < (calendar.date(byAdding: .weekOfYear, value: 1, to: starts[$0]) ?? .distantFuture) ? $0 : nil }
        }
        var created = Array(repeating: 0, count: starts.count), resolved = created
        var durations: [Double] = []
        for bug in bugs {
            if let index = weekIndex(bug.created) { created[index] += 1 }
            if let done = bug.resolved, let index = weekIndex(done) {
                resolved[index] += 1
                durations.append(max(0, done.timeIntervalSince(bug.created)) / 86_400)
            }
        }
        let rows = starts.indices.map { BugWeek(start: starts[$0], created: created[$0], resolved: resolved[$0]) }
        return BugResult(weeks: rows, openNow: openNow, openIsCapped: openIsCapped, medianDaysToResolve: FlowMetrics.median(durations))
    }
}
