import Foundation

/// The pieces of the expanded island that can be placed in a column. (The shortcuts dock is not one: it always sits
/// centred under the columns.)
public enum IslandBlock: String, CaseIterable, Codable, Sendable {
    case claude, pullRequests, jira, focus, history, music, alerts, briefing, timeline

    public var title: String {
        switch self {
        case .claude: return "Claude"
        case .pullRequests: return "Git"
        case .jira: return "Jira"
        case .focus: return "Foco"
        case .history: return "Histórico"
        case .music: return "Música"
        case .alerts: return "Avisos recentes"
        case .briefing: return "Resumo do dia"
        case .timeline: return "Linha do tempo"
        }
    }

    public var icon: String {
        switch self {
        case .claude: return "gauge.with.dots.needle.50percent"
        case .pullRequests: return "arrow.triangle.pull"
        case .jira: return "checklist"
        case .focus: return "timer"
        case .history: return "chart.bar"
        case .music: return "music.note"
        case .alerts: return "bell"
        case .briefing: return "sunrise"
        case .timeline: return "clock.arrow.circlepath"
        }
    }
}

/// Which blocks the island shows in which of its 1–3 equal-width columns, in order. The island is always symmetric
/// around the notch, so there is no "empty side": the column count alone sets the width.
public struct IslandLayoutConfig: Codable, Equatable, Sendable {
    public static let maxColumns = 3
    /// Most width that can be added to each column (pt).
    public static let maxExtraColumnWidth: Double = 120
    public private(set) var columns: [[IslandBlock]]
    /// Width added to every column on top of the default, so a layout can have wider (or, below zero, narrower) columns.
    public private(set) var extraColumnWidth: Double

    public init(columns: [[IslandBlock]], extraColumnWidth: Double = 0) {
        self.columns = columns
        self.extraColumnWidth = min(max(extraColumnWidth, -60), Self.maxExtraColumnWidth)
        normalize()
    }

    public func withExtraColumnWidth(_ extra: Double) -> IslandLayoutConfig {
        IslandLayoutConfig(columns: columns, extraColumnWidth: extra)
    }

    public static let vertical = IslandLayoutConfig(columns: [[.briefing, .claude, .pullRequests, .jira, .focus, .history, .music, .timeline, .alerts]])
    public static let twoColumns = IslandLayoutConfig(columns: [[.briefing, .claude, .focus, .music, .history, .alerts], [.pullRequests, .jira, .timeline]])
    public static let threeColumns = IslandLayoutConfig(columns: [[.briefing, .claude, .focus, .history], [.pullRequests, .jira], [.music, .timeline, .alerts]])

    public var columnCount: Int { columns.count }

    /// Total width of the island: 400 pt for one column (as it always was), 2 × 330 or 3 × 290 beyond that.
    public static func width(columns: Int) -> Double {
        switch columns {
        case ...1: return 400
        case 2: return 660
        default: return 870
        }
    }
    public var width: Double { Self.width(columns: columnCount) + Double(columnCount) * extraColumnWidth }
    public static var maxWidth: Double { width(columns: maxColumns) + Double(maxColumns) * maxExtraColumnWidth }

    /// 1–3 columns, every block exactly once (a repeated one keeps its first place; a missing one goes to the end of the first column).
    private mutating func normalize() {
        var seen = Set<IslandBlock>()
        var result = columns.prefix(Self.maxColumns).map { column in column.filter { seen.insert($0).inserted } }
        if result.isEmpty { result = [[]] }
        let missing = IslandBlock.allCases.filter { !seen.contains($0) }
        result[0] += missing
        columns = result
    }

    public func column(of block: IslandBlock) -> Int { columns.firstIndex { $0.contains(block) } ?? 0 }

    /// Moves a block to the end of another column.
    public func moving(_ block: IslandBlock, toColumn target: Int) -> IslandLayoutConfig {
        guard columns.indices.contains(target) else { return self }
        var copy = columns.map { $0.filter { $0 != block } }
        copy[target].append(block)
        return IslandLayoutConfig(columns: copy, extraColumnWidth: extraColumnWidth)
    }

    /// Moves a block one place up (-1) or down (+1) inside its column.
    public func shifting(_ block: IslandBlock, by offset: Int) -> IslandLayoutConfig {
        var copy = columns
        let c = column(of: block)
        guard let index = copy[c].firstIndex(of: block) else { return self }
        let target = index + offset
        guard copy[c].indices.contains(target) else { return self }
        copy[c].swapAt(index, target)
        return IslandLayoutConfig(columns: copy, extraColumnWidth: extraColumnWidth)
    }

    /// Changes the number of columns: removed columns hand their blocks to the last one kept; new columns start empty.
    public func resized(to count: Int) -> IslandLayoutConfig {
        let n = min(max(count, 1), Self.maxColumns)
        var copy = columns
        if n < copy.count {
            let extra = copy[n...].flatMap { $0 }
            copy = Array(copy[..<n])
            copy[n - 1] += extra
        } else {
            while copy.count < n { copy.append([]) }
        }
        return IslandLayoutConfig(columns: copy, extraColumnWidth: extraColumnWidth)
    }

    public static func decode(_ json: String?) -> IslandLayoutConfig {
        json?.data(using: .utf8).flatMap { try? JSONDecoder().decode(IslandLayoutConfig.self, from: $0) } ?? .vertical
    }

    public func encoded() -> String {
        (try? JSONEncoder().encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }

    /// "jiraApprovals", "sprint" and "outOfSprint" were blocks of their own; they now live inside the Jira card (the
    /// first one found keeps the place).
    private static func block(named name: String) -> IslandBlock? {
        ["jiraApprovals", "sprint", "outOfSprint"].contains(name) ? .jira : IslandBlock(rawValue: name)
    }

    // Decoding goes through the normalising initialiser, so a hand-edited or older value is repaired.
    private enum CodingKeys: String, CodingKey { case columns, extraColumnWidth }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let raw = try container.decode([[String]].self, forKey: .columns)
        let extra = try container.decodeIfPresent(Double.self, forKey: .extraColumnWidth) ?? 0
        self.init(columns: raw.map { $0.compactMap(Self.block(named:)) }, extraColumnWidth: extra)
    }
}
