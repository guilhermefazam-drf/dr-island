import SwiftUI
import DrIslandCore

/// The burndown's pills: how much is done, what the forecast leaves at the end, scope that came in after the start and,
/// in points, the warning about tasks without points (clicking it switches to tasks).
struct BurndownSummaryRow: View {
    @Environment(\.islandPalette) private var palette
    let result: BurndownResult
    let pace: SprintPace?
    let unit: MetricUnit
    let showsPointsWarning: Bool
    let switchToTasks: () -> Void

    var body: some View {
        Pill(BurndownSummary.doneText(result), Color(palette.accent))
        if let left = pace?.forecastLeft {
            if left < 0.5 {
                Pill("previsão: acaba a tempo", Color(palette.green))
            } else {
                Pill("previsão: sobram ~\(ManagementKPIs.format(left.rounded())) \(unitName)", Color(palette.amber))
            }
        }
        if showsPointsWarning {
            Button(action: switchToTasks) { Pill(BurndownSummary.missingPointsText(result), Color(palette.amber)) }
                .buttonStyle(.plain)
                .accessibilityLabel(BurndownSummary.missingPointsText(result))
                .accessibilityHint("Muda para a contagem em tasks")
        } else if let added = pace?.scopeAdded, added >= 0.5 {
            Pill("+\(ManagementKPIs.format(added)) \(unitName) de âmbito", Color(palette.neutral))
        }
    }

    private var unitName: String { unit == .points ? "pts" : "tasks" }
}
