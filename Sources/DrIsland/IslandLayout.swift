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
    static let prHeaderHeight: CGFloat = 26

    // The «Gestão» page: header strip, the burndown card (title, chart, legend, summary) and the gaps between.
    static let managementHeader: CGFloat = 24
    static let managementChart: CGFloat = 110
    static let managementSummary: CGFloat = 18
    static let managementFlowRow: CGFloat = 14
    /// A «Gestão» card's content: its title row, the chart, the legend and the summary.
    static func managementCardContent(_ m: IslandMetrics) -> CGFloat {
        CGFloat(m.cardHeader) + 6 + managementChart + 6 + 14 + 6 + managementSummary
    }
    static let managementCardGap: CGFloat = 8
    /// The cards of the «Gestão» page: four in a column, or two rows of two when the island is wide.
    static func managementGrid(columns: Int, metrics m: IslandMetrics) -> CGFloat {
        let rows: CGFloat = columns >= 2 ? 2 : 4
        return rows * CGFloat(m.card(Double(managementCardContent(m)))) + (rows - 1) * managementCardGap
    }

    // Content heights of the blocks; a block drawn on a card adds the density's card padding on each side.
    /// The Claude card's bar gauge under its header: the big percentage, the bar and the week row.
    static let claudeBarBody: CGFloat = 76
    static let forecastExtra: CGFloat = 27        // the "esgota às" chip and its spacing
    static let costTileHeight: CGFloat = 38
    static let costExtra: CGFloat = 8 + costTileHeight
    static let historyContent: CGFloat = 42
    static let shortcutsContent: CGFloat = 34
    static let alertsHeader: CGFloat = 16
    static let alertsRow: CGFloat = 22

    static func baseHeight(_ metrics: NotchMetrics) -> CGFloat { metrics.height + 116 }
    static func panelSize(_ metrics: NotchMetrics) -> CGSize {
        CGSize(width: CGFloat(IslandLayoutConfig.maxWidth) + 2 * overshootX, height: maxHeight(metrics) + overshootY)
    }

    /// The tallest island possible: every block in a single column, the lists fully expanded. Uses the roomiest
    /// density, so the panel is big enough for any.
    static func maxHeight(_ metrics: NotchMetrics) -> CGFloat {
        let m = IslandMetrics.forDensity(.regular)
        func card(_ content: CGFloat) -> CGFloat { CGFloat(m.card(Double(content))) }
        let prRowHeight = CGFloat(m.rowHeight), sectionSpacing = CGFloat(m.sectionSpacing)
        let claude = card(CGFloat(m.cardHeader) + 8 + max(claudeBarBody + forecastExtra, CGFloat(m.ringSize)) + costExtra)
        let blocks = claude + card(FocusBlock.contentHeight(m)) + card(MusicBlock.maxContentHeight(m)) + card(historyContent) + card(shortcutsContent)
            + card(16 + 6 + 4 * alertsRow) + card(BriefingBlock.contentHeight(rows: BriefingBlock.maxRows)) + card(TimelineBlock.contentHeight)
        let lists = 4 * (prHeaderHeight + CGFloat(expandedRowLimit + 2) * prRowHeight)
        return metrics.height + 6 + 10 + blocks + lists + 12 * sectionSpacing
    }
}
