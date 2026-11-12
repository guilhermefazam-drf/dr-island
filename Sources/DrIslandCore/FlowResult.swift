import Foundation

/// The numbers behind the flow chart.
public struct FlowResult: Equatable, Sendable {
    public var rows: [FlowStatusRow]
    public var stuck: [FlowStuckTask]
    /// Open tasks in the sprint that are flagged.
    public var flaggedOpen: Int

    public init(rows: [FlowStatusRow], stuck: [FlowStuckTask], flaggedOpen: Int) {
        self.rows = rows; self.stuck = stuck; self.flaggedOpen = flaggedOpen
    }
}
