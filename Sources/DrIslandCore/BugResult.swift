import Foundation

/// The numbers behind the bugs chart.
public struct BugResult: Equatable, Sendable {
    public var weeks: [BugWeek]
    /// Bugs still open now; `openIsCapped` when there were more than were read.
    public var openNow: Int
    public var openIsCapped: Bool
    /// Median days from opening to resolution, over the bugs resolved in the weeks shown.
    public var medianDaysToResolve: Double?

    public init(weeks: [BugWeek], openNow: Int, openIsCapped: Bool, medianDaysToResolve: Double?) {
        self.weeks = weeks; self.openNow = openNow; self.openIsCapped = openIsCapped; self.medianDaysToResolve = medianDaysToResolve
    }
}
