import AppKit
import SwiftUI
import DrIslandCore

/// One Jira task: status dot, key, summary, then priority, what changed, sprint goal, status and owner.
struct JiraTaskRow: View {
    let task: JiraTask
    /// The unseen change on this task (nil with row alerts off).
    let change: PRChange?
    let isMine: Bool
    @Environment(\.islandPalette) private var palette
    @Environment(\.islandMetrics) private var metrics

    var body: some View {
        Button { NSWorkspace.shared.open(task.url) } label: {
            HStack(spacing: 8) {
                if let symbol = Self.kindSymbol(task.kind, palette) {
                    Image(systemName: symbol.name).font(.caption2).foregroundStyle(symbol.color).islandTip(task.issueType ?? "")
                }
                Text(task.key).font(.caption2.monospacedDigit()).foregroundStyle(Color(palette.textSecondary))
                Text(task.summary).font(.caption).foregroundStyle(Color(palette.text).opacity(0.9)).lineLimit(1).truncationMode(.tail)
                Spacer(minLength: 4)
                if let symbol = Self.prioritySymbol(task.priority, palette) {
                    Image(systemName: symbol.name).font(.caption2).foregroundStyle(symbol.color).islandTip("Prioridade: " + (task.priority ?? ""))
                }
                if let change { RowTag(change.kind == .jiraStatus ? "novo estado" : change.label, change.tone.color(in: palette)) }
                if task.isSprintGoal { RowTag("★ sprint goal", Color(palette.amber)) }
                RowTag(task.status, task.category == .inProgress ? Color(palette.info) : Color(palette.neutral))
                OwnerTag(name: task.assignee, isMine: isMine)
            }
            .frame(height: CGFloat(metrics.rowHeight))
            .background {
                if let change {
                    RoundedRectangle(cornerRadius: 5).fill(change.tone.color(in: palette).opacity(0.16)).padding(.horizontal, -6)
                }
                else if task.isSprintGoal { RoundedRectangle(cornerRadius: 5).fill(Color(palette.amber).opacity(0.13)).padding(.horizontal, -6) }
                else if task.isFlagged { RoundedRectangle(cornerRadius: 5).fill(Color(palette.red).opacity(0.10)).padding(.horizontal, -6) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .islandTip((task.isSprintGoal ? "Sprint goal · " : "") + (task.issueType.map { "\($0) · " } ?? "") + task.summary)
    }

    /// A bug gets the bug icon in red; the other types a quiet icon so the list stays scannable.
    private static func kindSymbol(_ kind: JiraIssueKind, _ palette: IslandPalette) -> (name: String, color: Color)? {
        switch kind {
        case .bug: return ("ladybug.fill", Color(palette.red))
        case .feature: return ("sparkles", Color(palette.green))
        case .task: return ("checkmark.square", Color(palette.info))
        case .epic: return ("bolt.fill", Color(palette.purple))
        case .subtask: return ("arrow.turn.down.right", Color(palette.neutral))
        case .other: return nil
        }
    }

    private static func prioritySymbol(_ priority: String?, _ palette: IslandPalette) -> (name: String, color: Color)? {
        switch priority?.lowercased() {
        case "highest", "blocker", "critical": return ("chevron.up.2", Color(palette.red))
        case "high", "major": return ("chevron.up", Color(palette.amber))
        case "low", "minor": return ("chevron.down", Color(palette.accent))
        case "lowest", "trivial": return ("chevron.down.2", Color(palette.accent))
        default: return nil
        }
    }
}
