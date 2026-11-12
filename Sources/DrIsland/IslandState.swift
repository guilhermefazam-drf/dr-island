import AppKit
import SwiftUI
import DrIslandCore

@MainActor
@Observable
final class IslandState {
    var expanded = false
    /// Height of the visible expanded island (the panel itself is always max height); drives the hover hit area.
    var visibleHeight: CGFloat = 0
    var visibleWidth: CGFloat = 400
    /// The taller of the two pages: the island stays open while the pointer is anywhere over either, so turning to the
    /// shorter page does not leave the pointer outside it and close the island.
    var hitHeight: CGFloat = 0
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
    /// The page the island has settled on. `pageProgress` (0 = overview, 1 = management) follows the fingers while swiping.
    var page: IslandPage = .overview
    var pageProgress: Double = 0
    var isSwiping = false

    /// Settles on a page (after a swipe, from the dots or from the sprint card). Reduce Motion cross-fades instead of sliding.
    func go(to target: IslandPage) {
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.38, dampingFraction: 0.88)) {
            page = target
            pageProgress = Double(target.rawValue)
            isSwiping = false
        }
    }
}
