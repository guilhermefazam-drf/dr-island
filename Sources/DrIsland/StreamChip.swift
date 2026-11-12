import SwiftUI
import DrIslandCore

/// One stream (Jira board) the manager can look at.
struct StreamChip: View {
    let board: JiraBoard
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            Text(board.name)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(isSelected ? Color.white : Color.secondary)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(isSelected ? Brand.blue : Color.white.opacity(0.12)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Stream \(board.name)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
