import Foundation

public struct BurndownPoint: Equatable, Sendable {
    public var date: Date
    public var remaining: Double
    public var scope: Double
    public var ideal: Double

    public init(date: Date, remaining: Double, scope: Double, ideal: Double) {
        self.date = date; self.remaining = remaining; self.scope = scope; self.ideal = ideal
    }
}

public struct BurndownResult: Equatable, Sendable {
    public var points: [BurndownPoint]
    public var plannedScope: Double
    public var doneShare: Double
    public var flaggedOpen: Int
    public var daysLeft: Int
    public var isOverdue: Bool
    public var missingPointsShare: Double
    public var showsMissingPointsWarning: Bool
    /// Members of the sprint at the last instant, and how many of them have nil or 0 points.
    public var memberCount: Int = 0
    public var missingPointsCount: Int = 0

    public init(points: [BurndownPoint], plannedScope: Double, doneShare: Double, flaggedOpen: Int,
                daysLeft: Int, isOverdue: Bool, missingPointsShare: Double, showsMissingPointsWarning: Bool,
                memberCount: Int = 0, missingPointsCount: Int = 0) {
        self.points = points; self.plannedScope = plannedScope; self.doneShare = doneShare
        self.flaggedOpen = flaggedOpen; self.daysLeft = daysLeft; self.isOverdue = isOverdue
        self.missingPointsShare = missingPointsShare; self.showsMissingPointsWarning = showsMissingPointsWarning
        self.memberCount = memberCount; self.missingPointsCount = missingPointsCount
    }
}

public enum Burndown {
    /// Share of member tasks without points above which the UI should warn.
    public static let missingPointsWarning = 0.2

    public static func compute(_ snapshot: SprintSnapshot, unit: MetricUnit, now: Date,
                               calendar: Calendar) -> BurndownResult {
        let sprint = snapshot.sprint
        let issues = snapshot.issues
        let isOverdue = sprint.state != "closed" && sprint.end.map { now > $0 } ?? false

        let startDay = calendar.startOfDay(for: sprint.start ?? now)
        let endDay = calendar.startOfDay(for: sprint.end ?? now)
        let lastDay = isOverdue ? max(endDay, calendar.startOfDay(for: now))
                                : min(endDay, calendar.startOfDay(for: now))

        func weight(_ issue: SprintIssue, at instant: Date) -> Double {
            unit == .tasks ? 1 : (points(of: issue, at: instant) ?? 0)
        }
        func isDone(_ issue: SprintIssue, at instant: Date) -> Bool {
            snapshot.statusCategories[statusName(of: issue, at: instant)] == "done"
        }
        func measure(at instant: Date) -> (remaining: Double, scope: Double) {
            var remaining = 0.0, scope = 0.0
            for issue in issues where isMember(issue, sprintID: sprint.id, at: instant) {
                let w = weight(issue, at: instant)
                scope += w
                if !isDone(issue, at: instant) { remaining += w }
            }
            return (remaining, scope)
        }

        let plannedScope = measure(at: sprint.start ?? now).scope

        // Working days (Mon-Fri) of the sprint, for the ideal line.
        var workdays = 0
        var cursor = startDay
        while cursor <= endDay {
            if isWorkday(cursor, calendar) { workdays += 1 }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        var series: [BurndownPoint] = []
        var day = startDay
        var workdaysSoFar = 0
        var lastInstant = now
        while day <= lastDay {
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            if isWorkday(day, calendar) { workdaysSoFar += 1 }
            let instant = nextDay.addingTimeInterval(-0.001)
            let m = measure(at: instant)
            let ideal: Double
            if day > endDay || workdaysSoFar >= workdays { ideal = 0 }
            else if workdaysSoFar == 0 { ideal = plannedScope }
            else { ideal = plannedScope * Double(workdays - workdaysSoFar) / Double(workdays - 1) }
            series.append(BurndownPoint(date: day, remaining: m.remaining, scope: m.scope, ideal: ideal))
            lastInstant = instant
            day = nextDay
        }

        let doneShare: Double
        if let last = series.last, last.scope > 0 { doneShare = 1 - last.remaining / last.scope } else { doneShare = 0 }

        let members = issues.filter { isMember($0, sprintID: sprint.id, at: lastInstant) }
        let flaggedOpen = members.filter { $0.isFlagged && !isDone($0, at: lastInstant) }.count
        let missing = members.filter { (points(of: $0, at: lastInstant) ?? 0) == 0 }.count
        let missingShare = members.isEmpty ? 0 : Double(missing) / Double(members.count)

        let nowDay = calendar.startOfDay(for: now)
        let daysLeft = max(0, calendar.dateComponents([.day], from: nowDay, to: endDay).day ?? 0)

        return BurndownResult(
            points: series, plannedScope: plannedScope, doneShare: doneShare, flaggedOpen: flaggedOpen,
            daysLeft: daysLeft, isOverdue: isOverdue, missingPointsShare: missingShare,
            showsMissingPointsWarning: unit == .points && missingShare > missingPointsWarning,
            memberCount: members.count, missingPointsCount: missing)
    }

    // MARK: - State at an instant

    private static func isWorkday(_ date: Date, _ calendar: Calendar) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday != 1 && weekday != 7
    }

    private static func sprintIDs(_ text: String?) -> Set<String> {
        Set((text ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
    }

    private static func isMember(_ issue: SprintIssue, sprintID: Int, at instant: Date) -> Bool {
        let id = String(sprintID)
        let events = issue.events.filter { $0.kind == .sprint }.sorted { $0.date < $1.date }
        guard let first = events.first else { return true }
        var member = sprintIDs(first.from).contains(id)
        for event in events where event.date <= instant { member = sprintIDs(event.to).contains(id) }
        return member
    }

    private static func statusName(of issue: SprintIssue, at instant: Date) -> String {
        let events = issue.events.filter { $0.kind == .status }.sorted { $0.date < $1.date }
        guard let first = events.first else { return issue.status }
        var status = first.from ?? ""
        for event in events where event.date <= instant { status = event.to ?? "" }
        return status
    }

    private static func points(of issue: SprintIssue, at instant: Date) -> Double? {
        let events = issue.events.filter { $0.kind == .points }.sorted { $0.date < $1.date }
        guard let first = events.first else { return issue.points }
        var value = first.from.flatMap { Double($0) }
        for event in events where event.date <= instant { value = event.to.flatMap { Double($0) } }
        return value
    }
}
