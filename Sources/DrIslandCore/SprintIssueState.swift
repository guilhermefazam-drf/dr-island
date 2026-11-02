import Foundation

enum SprintIssueState {
    static func isWorkday(_ date: Date, _ calendar: Calendar) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday != 1 && weekday != 7
    }

    static func sprintIDs(_ text: String?) -> Set<String> {
        Set((text ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
    }

    static func isMember(_ issue: SprintIssue, sprintID: Int, at instant: Date) -> Bool {
        // Jira logs no event for values set at creation, so nothing is a member before the issue existed.
        guard instant >= issue.created else { return false }
        let id = String(sprintID)
        let events = issue.events.filter { $0.kind == .sprint }.sorted { $0.date < $1.date }
        guard let first = events.first else { return true }
        var member = sprintIDs(first.from).contains(id)
        for event in events where event.date <= instant { member = sprintIDs(event.to).contains(id) }
        return member
    }

    static func statusID(of issue: SprintIssue, at instant: Date) -> String {
        let events = issue.events.filter { $0.kind == .status }.sorted { $0.date < $1.date }
        guard let first = events.first else { return issue.statusID ?? "" }
        var status = first.from ?? ""
        for event in events where event.date <= instant { status = event.to ?? "" }
        return status
    }

    static func points(of issue: SprintIssue, at instant: Date) -> Double? {
        let events = issue.events.filter { $0.kind == .points }.sorted { $0.date < $1.date }
        guard let first = events.first else { return issue.points }
        var value = first.from.flatMap { Double($0) }
        for event in events where event.date <= instant { value = event.to.flatMap { Double($0) } }
        return value
    }
}
