import SwiftUI
import DrIslandCore

@MainActor
@Observable
final class IslandState {
    var expanded = false
    /// Height of the visible expanded island (the panel itself is always max height); drives the hover hit area.
    var visibleHeight: CGFloat = 0
    var visibleWidth: CGFloat = 400
    /// "+N mais" clicked: show the full list for that section until the island closes.
    var showAllPRs = false
    var showAllReviews = false
    var showAllJira = false
    /// Sprint lists opened with "+N mais": "t<sprint id>" for the tasks, "a<sprint id>" for the approvals.
    var expandedSprintLists: Set<String> = []
    var showAllApprovals = false
    /// Backlog groups (`BacklogGroup.id`) opened with "+N mais".
    var expandedBacklog: Set<String> = []
    /// The settings preview is driving the island, so closing it must not count as "the user saw the alerts".
    @ObservationIgnored var isPreview = false
    /// What the mini island shows while it is up; empty = hidden.
    var peek: [PRChange] = []
    /// An app is in full screen on this island's display: the border and the notification dots stay hidden (the mini island still shows).
    var fullscreen = false
    /// The launch splash has not played yet: the border and the dots wait for it. Cleared when the mini island folds back
    /// (or by `IslandInstance` if the splash never shows).
    var splashPending = Brand.logo != nil
}
