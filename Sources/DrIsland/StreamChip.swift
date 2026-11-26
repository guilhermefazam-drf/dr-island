import SwiftUI
import DrIslandCore

/// One stream (Jira board) the manager can look at, as a tab of the strip on top of the «Gestão» page.
struct StreamChip: View {
    let board: JiraBoard
    let isSelected: Bool
    let select: () -> Void
    @Environment(\.islandPalette) private var palette
    @Environment(\.islandMetrics) private var metrics

    var body: some View {
        Button(action: select) {
            Text(board.name)
                .font(.system(size: CGFloat(metrics.metaSize), weight: isSelected ? .semibold : .medium))
                .lineLimit(1)
                .foregroundStyle(Color(isSelected ? palette.text : palette.textSecondary))
                .padding(.horizontal, 9).padding(.vertical, 3)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color(palette.surface))
                            .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Stream \(board.name)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
