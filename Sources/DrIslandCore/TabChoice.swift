import Foundation

/// The two lists a card can switch between (Git: Meus / A rever; Jira: Tasks / Aprovações).
public enum TwoListTab: String, Sendable {
    case first, second
}

/// When a two-list card shows tabs, and which tab it opens on.
public enum TabChoice {
    /// Tabs only when the second list is enabled and both have something; otherwise the card shows a single list.
    /// `firstCount` counts rows (a status message counts); `secondCount` only real items.
    public static func tabs(firstCount: Int, secondCount: Int, secondEnabled: Bool) -> [TwoListTab] {
        secondEnabled && firstCount > 0 && secondCount > 0 ? [.first, .second] : []
    }

    /// Opening the island moves to the other tab when the current one has no items and the other has some, or when
    /// the other has unseen changes and the current one has none. Item counts default to "both have items".
    public static func onOpen(current: TwoListTab, firstUnseen: Int, secondUnseen: Int,
                              firstItems: Int = 1, secondItems: Int = 1) -> TwoListTab {
        let other: TwoListTab = current == .first ? .second : .first
        let (mineItems, otherItems) = current == .first ? (firstItems, secondItems) : (secondItems, firstItems)
        if mineItems == 0 && otherItems > 0 { return other }
        let (mine, theirs) = current == .first ? (firstUnseen, secondUnseen) : (secondUnseen, firstUnseen)
        guard mine == 0, theirs > 0, otherItems > 0 else { return current }
        return other
    }
}
