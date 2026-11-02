import Foundation

/// One week of the bugs chart.
public struct BugWeek: Equatable, Sendable, Identifiable {
    /// The first day of the week.
    public var start: Date
    public var created: Int
    public var resolved: Int
    public var id: Date { start }

    public init(start: Date, created: Int, resolved: Int) {
        self.start = start; self.created = created; self.resolved = resolved
    }
}
