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
            ListRow(key: task.key, title: task.summary, meta: meta, tint: tint) {
                // Always the same width, so a type with no icon does not shift the key and title.
                Group {
                    if let symbol = Self.kindSymbol(task.kind, palette) {
                        Image(systemName: symbol.name).font(.system(size: CGFloat(metrics.metaSize))).foregroundStyle(symbol.color)
                            .islandTip(task.issueType ?? "")
                    } else {
                        Color.clear
                    }
                }
                .frame(width: 14)
            } trailing: {
                if let symbol = Self.prioritySymbol(task.priority, palette) {
                    Image(systemName: symbol.name).font(.system(size: CGFloat(metrics.metaSize))).foregroundStyle(symbol.color)
                        .islandTip("Prioridade: " + (task.priority ?? ""))
                }
                if let change { Pill(change.kind == .jiraStatus ? "novo estado" : change.label, change.tone.color(in: palette)) }
                if task.isSprintGoal { Pill("★ sprint goal", Color(palette.amber)) }
                Pill(task.status, statusColor)
                Avatar(name: task.assignee, isMine: isMine)
            }
        }
        .buttonStyle(.plain)
        .islandTip((task.isSprintGoal ? "Sprint goal · " : "") + (task.issueType.map { "\($0) · " } ?? "") + task.summary)
    }

    /// The details line: the issue type, then the priority, or whose task it is when it is not the user's.
    private var meta: String {
        var parts: [String] = []
        if let type = task.issueType, !type.isEmpty { parts.append(type) }
        if !isMine, let assignee = task.assignee, !assignee.isEmpty { parts.append(assignee) }
        else if let priority = task.priority, !priority.isEmpty { parts.append(priority) }
        return parts.joined(separator: " · ")
    }

    /// The status by workflow category: in progress in the info colour, done in green, the rest neutral.
    private var statusColor: Color {
        switch task.category {
        case .inProgress: Color(palette.info)
        case .done: Color(palette.green)
        default: Color(palette.neutral)
        }
    }

    private var tint: Color? {
        if let change { return change.tone.color(in: palette).opacity(0.16) }
        if task.isSprintGoal { return Color(palette.amber).opacity(0.13) }
        if task.isFlagged { return Color(palette.red).opacity(0.10) }
        return nil
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
