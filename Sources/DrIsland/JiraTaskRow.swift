import AppKit
import SwiftUI
import DrIslandCore

/// One Jira task: status dot, key, summary, then priority, what changed, sprint goal, status and owner.
struct JiraTaskRow: View {
    let task: JiraTask
    /// The unseen change on this task (nil with row alerts off).
    let change: PRChange?
    let isMine: Bool

    var body: some View {
        Button { NSWorkspace.shared.open(task.url) } label: {
            HStack(spacing: 8) {
                Circle().fill(task.category == .inProgress ? Color.blue : Color.gray).frame(width: 7, height: 7).frame(width: 14)
                if let symbol = Self.kindSymbol(task.kind) {
                    Image(systemName: symbol.name).font(.caption2).foregroundStyle(symbol.color).islandTip(task.issueType ?? "")
                }
                Text(task.key).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                Text(task.summary).font(.caption).foregroundStyle(.white.opacity(0.9)).lineLimit(1).truncationMode(.tail)
                Spacer(minLength: 4)
                if let symbol = Self.prioritySymbol(task.priority) {
                    Image(systemName: symbol.name).font(.caption2).foregroundStyle(symbol.color).islandTip("Prioridade: " + (task.priority ?? ""))
                }
                if let change { RowTag(change.kind == .jiraStatus ? "novo estado" : change.label, change.tone.color) }
                if task.isSprintGoal { RowTag("★ sprint goal", .yellow) }
                RowTag(task.status, task.category == .inProgress ? .blue : .gray)
                OwnerTag(name: task.assignee, isMine: isMine)
            }
            .frame(height: IslandLayout.prRowHeight)
            .background {
                if let change {
                    RoundedRectangle(cornerRadius: 5).fill(change.tone.color.opacity(0.16)).padding(.horizontal, -6)
                }
                else if task.isSprintGoal { RoundedRectangle(cornerRadius: 5).fill(Color.yellow.opacity(0.13)).padding(.horizontal, -6) }
                else if task.isFlagged { RoundedRectangle(cornerRadius: 5).fill(Color.red.opacity(0.10)).padding(.horizontal, -6) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .islandTip((task.isSprintGoal ? "Sprint goal · " : "") + (task.issueType.map { "\($0) · " } ?? "") + task.summary)
    }

    /// A bug gets the bug icon in red; the other types a quiet icon so the list stays scannable.
    private static func kindSymbol(_ kind: JiraIssueKind) -> (name: String, color: Color)? {
        switch kind {
        case .bug: return ("ladybug.fill", .red)
        case .feature: return ("sparkles", .green)
        case .task: return ("checkmark.square", .blue)
        case .epic: return ("bolt.fill", .purple)
        case .subtask: return ("arrow.turn.down.right", .gray)
        case .other: return nil
        }
    }

    private static func prioritySymbol(_ priority: String?) -> (name: String, color: Color)? {
        switch priority?.lowercased() {
        case "highest", "blocker", "critical": return ("chevron.up.2", .red)
        case "high", "major": return ("chevron.up", .orange)
        case "low", "minor": return ("chevron.down", .teal)
        case "lowest", "trivial": return ("chevron.down.2", .teal)
        default: return nil
        }
    }
}
