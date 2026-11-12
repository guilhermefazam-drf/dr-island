import SwiftUI
import DrIslandCore

/// «62% concluído · 3 bloqueadas · acaba em 4 dias», as the island's small tags, plus the missing-points warning.
struct BurndownSummaryRow: View {
    let result: BurndownResult
    let deadline: BurndownSummary.Deadline
    let showsPointsWarning: Bool
    let switchToTasks: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            RowTag(BurndownSummary.doneText(result), Brand.blue)
            RowTag(BurndownSummary.flaggedText(result), result.flaggedOpen > 0 ? Brand.red : .gray)
            RowTag(BurndownSummary.text(deadline), deadlineColor)
            Spacer(minLength: 0)
            if showsPointsWarning {
                Button(action: switchToTasks) { RowTag(BurndownSummary.missingPointsText(result), Brand.amber) }
                    .buttonStyle(.plain)
                    .accessibilityLabel(BurndownSummary.missingPointsText(result))
                    .accessibilityHint("Muda para a contagem em tasks")
            }
        }
        .frame(height: IslandLayout.managementSummary)
    }

    private var deadlineColor: Color {
        switch deadline {
        case .overdue: return Brand.red
        case .today: return Brand.amber
        case .closed, .days: return .gray
        }
    }
}
