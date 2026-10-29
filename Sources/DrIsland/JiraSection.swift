import SwiftUI
import DrIslandCore

/// One list of the Jira card ("As minhas tasks", "Aprovações", "Fora da Sprint"); nothing when it has no rows.
struct JiraSection: View {
    let title: String
    let rows: [JiraRow]
    /// Unseen changes to tag rows with (empty with row alerts off).
    let changes: [PRChange]
    /// The user's Jira name, to mark their own tasks.
    let myName: String?
    /// "+N mais" / "mostrar menos".
    let showAll: (Bool) -> Void

    var body: some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ListSectionHeader(title: title)
                ForEach(rows) { row in
                    switch row {
                    case .task(let task):
                        JiraTaskRow(task: task, change: changes.last { $0.prID == "jira-" + task.key },
                                    isMine: task.assignee != nil && task.assignee == myName)
                    case .message(let text): ListNote(text: text)
                    case .more(let count): ListExpander(title: "+\(count) mais") { showAll(true) }
                    case .less: ListExpander(title: "mostrar menos") { showAll(false) }
                    case .overflow(let count): ListNote(text: "+\(count) não listados", small: true)
                    }
                }
            }
        }
    }
}
