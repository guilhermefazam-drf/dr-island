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

    /// Opening the island moves to the other tab only when it has unseen changes and the current one has none.
    public static func onOpen(current: TwoListTab, firstUnseen: Int, secondUnseen: Int) -> TwoListTab {
        let (mine, other) = current == .first ? (firstUnseen, secondUnseen) : (secondUnseen, firstUnseen)
        guard mine == 0, other > 0 else { return current }
        return current == .first ? .second : .first
    }
}
