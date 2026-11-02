import Foundation

/// Where the sprint's work is, how long it stays in each status and what is stuck. Pure, built from the snapshot.
public enum FlowMetrics {
    /// A task in the same status for this many days (or more) is listed as stuck.
    public static let stuckDays = 3.0
    /// At most this many stuck tasks are listed.
    public static let stuckLimit = 3

    public static func compute(_ snapshot: SprintSnapshot, unit: MetricUnit, now: Date) -> FlowResult {
        let sprintID = snapshot.sprint.id
        let members = snapshot.issues.filter { SprintIssueState.isMember($0, sprintID: sprintID, at: now) }
        func weight(_ issue: SprintIssue) -> Double { unit == .tasks ? 1 : (SprintIssueState.points(of: issue, at: now) ?? 0) }
        func name(_ id: String, fallback: String) -> String { snapshot.statusNames[id] ?? (fallback.isEmpty ? id : fallback) }

        // Amount per status now.
        var amount: [String: Double] = [:], displayName: [String: String] = [:]
        for issue in members {
            let id = SprintIssueState.statusID(of: issue, at: now)
            amount[id, default: 0] += weight(issue)
            displayName[id] = name(id, fallback: issue.status)
        }

        // Time spent per status, from the finished stays of the members.
        var stays: [String: [Double]] = [:]
        for issue in members {
            for stay in finishedStays(of: issue) { stays[stay.status, default: []].append(stay.days) }
        }

        let order = ["new": 0, "indeterminate": 1, "done": 2]
        let rows = amount.keys.map { id in
            FlowStatusRow(id: id, name: displayName[id] ?? id, category: snapshot.statusCategories[id] ?? "indeterminate",
                          amount: amount[id] ?? 0, medianDays: median(stays[id] ?? []))
        }.sorted {
            let (a, b) = (order[$0.category] ?? 1, order[$1.category] ?? 1)
            return a != b ? a < b : $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        // Open tasks that are flagged or have sat in one status for a while.
        var candidates: [FlowStuckTask] = []
        var flaggedOpen = 0
        for issue in members {
            let id = SprintIssueState.statusID(of: issue, at: now)
            guard snapshot.statusCategories[id] != "done" else { continue }
            if issue.isFlagged { flaggedOpen += 1 }
            let days = max(0, now.timeIntervalSince(enteredCurrentStatus(issue, now: now))) / 86_400
            if issue.isFlagged || days >= stuckDays {
                candidates.append(FlowStuckTask(key: issue.key, statusName: name(id, fallback: issue.status), days: days, isFlagged: issue.isFlagged))
            }
        }
        let stuck = candidates.sorted { $0.isFlagged != $1.isFlagged ? $0.isFlagged : $0.days > $1.days }.prefix(stuckLimit)
        return FlowResult(rows: rows, stuck: Array(stuck), flaggedOpen: flaggedOpen)
    }

    /// When the issue entered the status it is in now.
    static func enteredCurrentStatus(_ issue: SprintIssue, now: Date) -> Date {
        let events = issue.events.filter { $0.kind == .status && $0.date <= now }.sorted { $0.date < $1.date }
        return events.last?.date ?? issue.created
    }

    /// The stays that ended (the issue moved on), each as the status id and the days it lasted.
    static func finishedStays(of issue: SprintIssue) -> [(status: String, days: Double)] {
        let events = issue.events.filter { $0.kind == .status }.sorted { $0.date < $1.date }
        guard let first = events.first else { return [] }
        var result: [(String, Double)] = []
        var status = first.from ?? ""
        var since = issue.created
        for event in events {
            if !status.isEmpty { result.append((status, max(0, event.date.timeIntervalSince(since)) / 86_400)) }
            status = event.to ?? ""
            since = event.date
        }
        return result
    }

    static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count % 2 == 1 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2
    }
}
