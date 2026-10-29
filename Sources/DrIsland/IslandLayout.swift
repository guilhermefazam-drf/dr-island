import SwiftUI
import DrIslandCore

enum IslandLayout {
    /// Spare room around the island so the springs can overshoot without being clipped by the panel.
    static let overshootX: CGFloat = 24
    static let overshootY: CGFloat = 28
    static let maxPullRequestRows = 4
    static let maxJiraRows = 4
    static let maxPeekRows = 4
    static let peekWidth: CGFloat = 320
    static let peekRowHeight: CGFloat = 22
    /// The launch splash row: the Doutor Finanças logo, taller than an alert row.
    static let splashRowHeight: CGFloat = 40
    /// Rows shown per section after "+N mais" (anything beyond is summarised).
    static let expandedRowLimit = 8
    static let prRowHeight: CGFloat = 25
    static let prHeaderHeight: CGFloat = 26
    /// A list inside a card: its title row (shorter, the card already pads the top) and the rule between two lists.
    static let cardListHeader: CGFloat = 20
    static let listRule: CGFloat = 13
    /// The title row of a Git / Jira card (a 16 pt label and the gap under it).
    static let cardTitle: CGFloat = 20

    static let sectionSpacing: CGFloat = 16
    static let cardPadding: CGFloat = 10
    // Content heights of the blocks; a block drawn on a card adds `cardPadding` on each side.
    static let claudeHeight: CGFloat = 100
    static let claudeRingHeight: CGFloat = 108   // header + a 84 pt ring; the forecast fits beside it
    static let forecastExtra: CGFloat = 27        // the "esgota às" chip and its spacing
    static let costTileHeight: CGFloat = 38
    static let costExtra: CGFloat = 8 + costTileHeight
    static let focusContent: CGFloat = 56
    static let musicContent: CGFloat = 70
    static let musicContentWithProgress: CGFloat = 84
    static let historyContent: CGFloat = 42
    static let shortcutsContent: CGFloat = 34
    static let alertsHeader: CGFloat = 16
    static let alertsRow: CGFloat = 22
    static func card(_ content: CGFloat) -> CGFloat { content + 2 * cardPadding }

    static func baseHeight(_ metrics: NotchMetrics) -> CGFloat { metrics.height + 116 }
    static func panelSize(_ metrics: NotchMetrics) -> CGSize {
        CGSize(width: CGFloat(IslandLayoutConfig.maxWidth) + 2 * overshootX, height: maxHeight(metrics) + overshootY)
    }

    /// The tallest island possible: every block in a single column, the lists fully expanded.
    static func maxHeight(_ metrics: NotchMetrics) -> CGFloat {
        let blocks = max(claudeHeight + forecastExtra, claudeRingHeight) + costExtra + card(focusContent) + card(musicContentWithProgress) + card(historyContent) + card(shortcutsContent)
            + card(16 + 6 + 4 * alertsRow) + card(BriefingBlock.contentHeight(rows: BriefingBlock.maxRows)) + card(TimelineBlock.contentHeight)
        let lists = 4 * (prHeaderHeight + CGFloat(expandedRowLimit + 2) * prRowHeight)
        return metrics.height + 6 + 10 + blocks + lists + 12 * sectionSpacing
    }
}
