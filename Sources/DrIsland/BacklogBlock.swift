import SwiftUI
import DrIslandCore

/// The "Backlog" card: the team backlog as in Jira, one list per future sprint and then the tasks with no sprint.
struct BacklogBlock: View {
    struct Group: Identifiable {
        let id: String
        let title: String
        let rows: [JiraRow]
    }

    let groups: [Group]
    /// Shown when the card has no groups ("A carregar…", "Backlog vazio", an error).
    let message: String?
    /// More tasks than were read: a note at the end.
    let truncated: Bool
    let changes: [PRChange]
    let myName: String?
    let showAll: (String, Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardTitle(title: "Backlog", icon: "tray.full")
            if let message { ListNote(text: message) }
            ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                if index > 0 { ListRule() }
                JiraSection(title: group.title, rows: group.rows, changes: changes, myName: myName) { showAll(group.id, $0) }
            }
            if truncated && !groups.isEmpty { ListNote(text: "Só as primeiras 100 tasks do backlog", small: true) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .blockCard()
    }

    static func contentHeight(groups: [Group], message: String?, truncated: Bool) -> CGFloat {
        let lists = groups.map { IslandLayout.cardListHeader + 2 + CGFloat($0.rows.count) * IslandLayout.prRowHeight }
        return IslandLayout.cardTitle + lists.reduce(0, +) + CGFloat(max(groups.count - 1, 0)) * IslandLayout.listRule
            + (message == nil ? 0 : IslandLayout.prRowHeight) + (truncated && !groups.isEmpty ? IslandLayout.prRowHeight : 0)
    }
}
