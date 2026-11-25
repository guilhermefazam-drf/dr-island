import Foundation

/// The Bento style's composition rules, free of UI so they can be tested.
public enum BentoLayout {
    /// The big numbers on top.
    public enum KPI: String, CaseIterable, Sendable {
        case claude, pullRequests, sprint, focus, jira, alerts
    }

    /// Numbers per row: two (a 2 × 2 grid) in one column, four in two, six in three.
    public static func perRow(columns: Int) -> Int {
        switch columns {
        case ...1: 2
        case 2: 4
        default: 6
        }
    }

    /// Claude, PRs, sprint and focus; with three columns also Jira and alerts. Sources that are off are left out.
    public static func kpis(columns: Int, available: Set<KPI>) -> [KPI] {
        let wanted: [KPI] = columns >= 3 ? [.claude, .pullRequests, .sprint, .focus, .jira, .alerts]
            : [.claude, .pullRequests, .sprint, .focus]
        return wanted.filter(available.contains)
    }

    /// Rows of numbers for `count` numbers.
    public static func kpiRows(count: Int, columns: Int) -> Int {
        let per = perRow(columns: columns)
        return count == 0 ? 0 : (count + per - 1) / per
    }

    /// Blocks shown elsewhere in Bento: Claude and focus as numbers, music in the dock and, under three columns,
    /// the alerts in the events strip.
    public static func isHeldOutside(_ block: IslandBlock, columns: Int) -> Bool {
        switch block {
        case .claude, .focus, .music: true
        case .alerts: columns < 3
        default: false
        }
    }

    /// The user's blocks in reading order (column by column), minus those shown elsewhere.
    public static func listBlocks(_ layout: IslandLayoutConfig) -> [IslandBlock] {
        layout.columns.flatMap { $0 }.filter { !isHeldOutside($0, columns: layout.columnCount) }
    }

    /// Spreads blocks over `columns` columns, each going to the currently shortest one, so the columns end up
    /// about the same height; the order is kept inside each column.
    public static func distribute(_ blocks: [IslandBlock], columns: Int, gap: Double,
                                  height: (IslandBlock) -> Double) -> [[IslandBlock]] {
        let count = max(columns, 1)
        var out = Array(repeating: [IslandBlock](), count: count)
        var heights = Array(repeating: 0.0, count: count)
        for block in blocks {
            let i = heights.indices.min { heights[$0] < heights[$1] }!
            heights[i] += (out[i].isEmpty ? 0 : gap) + height(block)
            out[i].append(block)
        }
        return out
    }
}
