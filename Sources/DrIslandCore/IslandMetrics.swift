import Foundation

/// The sizes of the island's cards, rows and type for one density. Views and the height maths both read these,
/// so what is drawn and the panel size always agree.
public struct IslandMetrics: Equatable, Sendable {
    public var cardPadding: Double
    /// Vertical space between two cards in a column.
    public var cardGap: Double
    public var cardRadius: Double
    public var rowHeight: Double
    /// Rows show a second, smaller line of details (repository, type, assignee…).
    public var rowHasMeta: Bool
    /// The title row of a list inside a card ("Os meus PRs", "Aprovações").
    public var listHeader: Double
    /// The rule (and its spacing) between two lists in one card.
    public var listRule: Double
    /// The card's own title row.
    public var cardHeader: Double
    public var tile: Double
    public var titleSize: Double
    public var bodySize: Double
    public var metaSize: Double
    public var ringSize: Double
    public var dockIcon: Double
    /// Space between the columns' blocks and before the shortcuts dock.
    public var sectionSpacing: Double

    public static func forDensity(_ density: IslandDensity) -> IslandMetrics {
        switch density {
        // Starts with the island's original sizes; the «Camadas» values replace them when the new look lands.
        case .regular, .compact: regular
        }
    }

    public static let regular = IslandMetrics(
        cardPadding: 10, cardGap: 16, cardRadius: 12, rowHeight: 25, rowHasMeta: false,
        listHeader: 20, listRule: 13, cardHeader: 20, tile: 16,
        titleSize: 11, bodySize: 11, metaSize: 10, ringSize: 84, dockIcon: 30, sectionSpacing: 16)

    /// A card's height for content of the given height.
    public func card(_ content: Double) -> Double { content + 2 * cardPadding }

    /// A titled list: nothing when empty, otherwise its header, a 2 pt gap and the rows.
    public func listSection(rows: Int) -> Double {
        rows == 0 ? 0 : listHeader + 2 + Double(rows) * rowHeight
    }

    /// A card holding titled lists one under the other (empty ones take no room), separated by rules.
    public func listCard(sections: [Int]) -> Double {
        let nonEmpty = sections.filter { $0 > 0 }
        let lists = nonEmpty.reduce(0) { $0 + listSection(rows: $1) }
        return card(cardHeader + lists + Double(max(nonEmpty.count - 1, 0)) * listRule)
    }
}
