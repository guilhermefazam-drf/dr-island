import Foundation

/// One status of the flow chart: how much work sits in it now and how long work usually stays in it.
public struct FlowStatusRow: Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    /// `"new"`, `"indeterminate"` or `"done"`.
    public var category: String
    /// Tasks (or points) in this status now.
    public var amount: Double
    /// Median days work stayed here, over the stays that have ended; nil with no finished stay.
    public var medianDays: Double?

    public init(id: String, name: String, category: String, amount: Double, medianDays: Double?) {
        self.id = id; self.name = name; self.category = category; self.amount = amount; self.medianDays = medianDays
    }
}
