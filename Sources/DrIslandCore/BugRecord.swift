import Foundation

/// A bug as the bugs chart needs it: when it was opened and, if it was, when it was resolved.
public struct BugRecord: Equatable, Sendable {
    public var key: String
    public var created: Date
    public var resolved: Date?

    public init(key: String, created: Date, resolved: Date?) {
        self.key = key; self.created = created; self.resolved = resolved
    }
}
