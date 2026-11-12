import Foundation

/// A task worth a look: flagged, or in the same status for a while.
public struct FlowStuckTask: Equatable, Sendable, Identifiable {
    public var key: String
    public var statusName: String
    public var days: Double
    public var isFlagged: Bool
    public var id: String { key }

    public init(key: String, statusName: String, days: Double, isFlagged: Bool) {
        self.key = key; self.statusName = statusName; self.days = days; self.isFlagged = isFlagged
    }
}
