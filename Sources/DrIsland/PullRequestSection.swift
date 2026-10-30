import SwiftUI
import DrIslandCore

/// One list of the Git card ("Os meus PRs", "A rever"); nothing when it has no rows.
struct PullRequestSection: View {
    let list: PRList
    let rows: [PRRow]
    /// Unseen changes to tag rows with (empty with row alerts off).
    let changes: [PRChange]
    /// "+N mais" / "mostrar menos".
    let showAll: (Bool) -> Void

    var body: some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ListSectionHeader(title: title)
                ForEach(rows) { row in
                    switch row {
                    case .pr(let pr): PullRequestRow(pr: pr, change: changes.last { $0.prID == pr.id })
                    case .message(let text): ListNote(text: text)
                    case .more(let count): ListExpander(title: "+\(count) mais") { showAll(true) }
                    case .less: ListExpander(title: "mostrar menos") { showAll(false) }
                    case .overflow(let count): ListNote(text: "+\(count) não listados", small: true)
                    }
                }
            }
        }
    }

    private var title: String {
        switch list {
        case .authored: "Os meus PRs"
        case .review: "A rever"
        }
    }
}
