import Foundation
import DrIslandCore

/// A made-up sprint for `DR_ISLAND_FAKE_MANAGEMENT=1`, so the «Gestão» page can be seen (and photographed) without Jira.
enum ManagementDemo {
    static let boards = [JiraBoard(id: 483, name: "Clínica"), JiraBoard(id: 846, name: "Plataforma"), JiraBoard(id: 717, name: "Backoffice")]

    static func sprints(now: Date = Date()) -> [SprintRecord] {
        let day = 86_400.0
        return [
            SprintRecord(id: 7648, name: "SPRINT #18_Clínica", boardID: 483, start: now - 8 * day, end: now + 5 * day, state: "active", completedAt: nil),
            SprintRecord(id: 7184, name: "SPRINT #17_Clínica", boardID: 483, start: now - 22 * day, end: now - 9 * day, state: "closed", completedAt: now - 9 * day),
        ]
    }

    static func snapshot(now: Date = Date()) -> SprintSnapshot {
        let day = 86_400.0
        let sprint = sprints(now: now)[0]
        let start = sprint.start ?? now
        func done(_ key: String, points: Double, after days: Double, flagged: Bool = false) -> SprintIssue {
            SprintIssue(key: key, type: "Story", points: points, status: "Concluído", statusID: "3", isFlagged: flagged, created: start - day, resolved: start + days * day,
                        events: [SprintIssueEvent(date: start + (days - 1.5) * day, kind: .status, from: "1", to: "2"),
                                 SprintIssueEvent(date: start + days * day, kind: .status, from: "2", to: "3")])
        }
        func open(_ key: String, points: Double?, status: String = "Em curso", id: String = "2", flagged: Bool = false, since days: Double = 1) -> SprintIssue {
            let moved = id == "1" ? [] : [SprintIssueEvent(date: now - days * day, kind: .status, from: "1", to: id)]
            return SprintIssue(key: key, type: "Story", points: points, status: status, statusID: id, isFlagged: flagged, created: start - day, resolved: nil, events: moved)
        }
        let issues = [
            done("TEP-1", points: 3, after: 1.5), done("TEP-2", points: 5, after: 3), done("TEP-3", points: 2, after: 4.5),
            done("TEP-4", points: 3, after: 6), done("TEP-5", points: 5, after: 7),
            open("TEP-6", points: 5, since: 5), open("TEP-7", points: 3, flagged: true, since: 2), open("TEP-8", points: 2, status: "Por fazer", id: "1"),
            open("TEP-9", points: nil, since: 1), open("TEP-10", points: 5, status: "Por fazer", id: "1"),
        ]
        return SprintSnapshot(sprint: sprint, issues: issues, statusCategories: ["1": "new", "2": "indeterminate", "3": "done"], fetchedAt: now,
                              statusNames: ["1": "Por fazer", "2": "Em curso", "3": "Concluído"])
    }

    /// Five closed sprints with a different amount done each, for the velocity chart.
    static func closedSnapshots(now: Date = Date()) -> [SprintSnapshot] {
        let day = 86_400.0
        return [(14, 9, 7), (15, 10, 9), (16, 8, 8), (17, 11, 8), (18, 9, 9)].enumerated().map { index, spec in
            let start = now - Double(8 + (5 - index) * 14) * day
            let record = SprintRecord(id: 7000 + index, name: "SPRINT #\(spec.0)_Clínica", boardID: 483, start: start, end: start + 13 * day, state: "closed", completedAt: start + 13 * day)
            let issues = (0..<spec.1).map { n -> SprintIssue in
                let finished = n < spec.2
                return SprintIssue(key: "V\(index)-\(n)", type: "Story", points: Double(2 + n % 3), status: finished ? "Concluído" : "Por fazer", statusID: finished ? "3" : "1", isFlagged: false,
                                   created: start - day, resolved: nil,
                                   events: finished ? [SprintIssueEvent(date: start + Double(3 + n) * day, kind: .status, from: "1", to: "3")] : [])
            }
            return SprintSnapshot(sprint: record, issues: issues, statusCategories: ["1": "new", "3": "done"], fetchedAt: now)
        }
    }

    /// Eight weeks of bugs for the bugs chart.
    static func bugs(now: Date = Date()) -> BugResult {
        let week = 7 * 86_400.0
        let created = [3, 5, 2, 4, 6, 3, 4, 5], resolved = [2, 4, 3, 3, 4, 5, 3, 2]
        let weeks = (0..<8).map { BugWeek(start: now - Double(7 - $0) * week, created: created[$0], resolved: resolved[$0]) }
        return BugResult(weeks: weeks, openNow: 14, openIsCapped: false, medianDaysToResolve: 3.5)
    }
}
