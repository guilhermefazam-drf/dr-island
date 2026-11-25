import SwiftUI
import DrIslandCore

/// «62% concluído · 3 bloqueadas · acaba em 4 dias», as the island's small tags, plus the missing-points warning.
struct BurndownSummaryRow: View {
    @Environment(\.islandPalette) private var palette
    let result: BurndownResult
    let deadline: BurndownSummary.Deadline
    let showsPointsWarning: Bool
    let switchToTasks: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            RowTag(BurndownSummary.doneText(result), Color(palette.accent))
            RowTag(BurndownSummary.flaggedText(result), result.flaggedOpen > 0 ? Color(palette.red) : Color(palette.neutral))
            RowTag(BurndownSummary.text(deadline), deadlineColor)
            Spacer(minLength: 0)
            if showsPointsWarning {
                Button(action: switchToTasks) { RowTag(BurndownSummary.missingPointsText(result), Color(palette.amber)) }
                    .buttonStyle(.plain)
                    .accessibilityLabel(BurndownSummary.missingPointsText(result))
                    .accessibilityHint("Muda para a contagem em tasks")
            }
        }
        .frame(height: IslandLayout.managementSummary)
    }

    private var deadlineColor: Color {
        switch deadline {
        case .overdue: return Color(palette.red)
        case .today: return Color(palette.amber)
        case .closed, .days: return Color(palette.neutral)
        }
    }
}
