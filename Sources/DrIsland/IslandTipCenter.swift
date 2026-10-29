import Observation

/// The tooltip on show, one per island. Hovered views only write it and `IslandTipLayer` alone reads it, so a hover
/// redraws the bubble, not the island. (It used to be a setter closure in the environment: a new closure on every
/// island redraw, which refreshed every view with a tooltip.)
@MainActor
@Observable
final class IslandTipCenter {
    var tip: IslandTipData?
}
