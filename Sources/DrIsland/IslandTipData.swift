import AppKit
import SwiftUI
import DrIslandCore

/// The island's own tooltip. The native `.help` never shows here: the island is a non-activating panel of an app that is
/// never frontmost, and AppKit only shows tooltips for the active app. So a hovered view reports its frame here and
/// `IslandView` draws the bubble inside the visible island, where it is never cut at the edges.
struct IslandTipData: Equatable {
    let text: String
    /// The hovered view's frame in the island's `islandRoot` coordinate space.
    let anchor: CGRect
}

let islandRootSpace = "islandRoot"
