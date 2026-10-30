import Foundation

/// A Jira sprint as needed by the management charts. `state` is `"active"`, `"closed"` or `"future"`.
public struct SprintRecord: Codable, Equatable, Sendable {
    public var id: Int
    public var name: String
    public var boardID: Int
    public var start: Date?
    public var end: Date?
    public var state: String
    public var completedAt: Date?

    public init(id: Int, name: String, boardID: Int, start: Date?, end: Date?, state: String, completedAt: Date?) {
        self.id = id; self.name = name; self.boardID = boardID
        self.start = start; self.end = end; self.state = state; self.completedAt = completedAt
    }
}

/// One changelog entry of an issue that matters for the burndown.
public struct SprintIssueEvent: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case status, sprint, points }

    public var date: Date
    public var kind: Kind
    /// Status name; comma-separated sprint ids; or the story-point value as text.
    public var from: String?
    public var to: String?

    public init(date: Date, kind: Kind, from: String?, to: String?) {
        self.date = date; self.kind = kind; self.from = from; self.to = to
    }
}

public struct SprintIssue: Codable, Equatable, Sendable {
    public var key: String
    public var type: String?
    public var points: Double?
    public var status: String
    public var isFlagged: Bool
    public var created: Date
    public var resolved: Date?
    /// Chronological order.
    public var events: [SprintIssueEvent]

    public init(key: String, type: String?, points: Double?, status: String, isFlagged: Bool,
                created: Date, resolved: Date?, events: [SprintIssueEvent]) {
        self.key = key; self.type = type; self.points = points; self.status = status
        self.isFlagged = isFlagged; self.created = created; self.resolved = resolved; self.events = events
    }
}

public struct SprintSnapshot: Codable, Equatable, Sendable {
    public var sprint: SprintRecord
    public var issues: [SprintIssue]
    /// Status name → `"new"`, `"indeterminate"` or `"done"`.
    public var statusCategories: [String: String]
    public var fetchedAt: Date

    public init(sprint: SprintRecord, issues: [SprintIssue], statusCategories: [String: String], fetchedAt: Date) {
        self.sprint = sprint; self.issues = issues
        self.statusCategories = statusCategories; self.fetchedAt = fetchedAt
    }
}

public enum MetricUnit: String, Sendable { case points, tasks }
