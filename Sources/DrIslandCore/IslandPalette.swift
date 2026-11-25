import Foundation

/// The colour tokens of one island theme. Views read these instead of literal colours.
public struct IslandPalette: Equatable, Sendable {
    /// The island's background, top to bottom (one stop = flat colour).
    public var base: [ThemeColor]
    /// The colour right under the physical notch (the Claro theme keeps it black).
    public var collar: ThemeColor
    public var surface: ThemeColor
    public var surfaceRaised: ThemeColor
    public var border: ThemeColor
    /// The 1 pt light line along the top edge of a card.
    public var highlight: ThemeColor
    public var text: ThemeColor
    public var textSecondary: ThemeColor
    public var textTertiary: ThemeColor
    public var accent: ThemeColor
    public var green: ThemeColor
    public var amber: ThemeColor
    public var red: ThemeColor
    public var purple: ThemeColor
    public var pink: ThemeColor
    public var orange: ThemeColor
    public var isLight: Bool

    /// The colour that identifies where a block's data comes from (its tile, alert dot and pulse).
    public func source(_ block: IslandBlock) -> ThemeColor {
        switch block {
        case .claude: orange
        case .pullRequests: purple
        case .sprint, .jira, .backlog, .history, .timeline: accent
        case .focus: green
        case .music: pink
        case .alerts, .briefing: amber
        }
    }
}
