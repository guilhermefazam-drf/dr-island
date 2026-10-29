import SwiftUI
import DrIslandCore

enum JiraRow: Identifiable {
    case task(JiraTask)
    case message(String)
    case more(Int)       // collapsed: expands the section
    case less            // expanded: collapses it again
    case overflow(Int)   // expanded but still more than fits; not clickable

    /// A task keeps its row while others come and go; the trailing rows keep theirs while their count changes.
    var id: String {
        switch self {
        case .task(let task): "task:\(task.id)"
        case .message: "message"
        case .more: "more"
        case .less: "less"
        case .overflow: "overflow"
        }
    }
}
