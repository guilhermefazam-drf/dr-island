import SwiftUI
import DrIslandCore

/// The burndown of the selected sprint: the chart with its forecast, the legend in the header and the summary pills.
struct BurndownCard: View {
    @Environment(\.islandPalette) private var palette
    @Environment(\.islandMetrics) private var metrics
    let store: ManagementStore

    var body: some View {
        // `burndown` recomputes on every read (it uses `Date()`): read it once per render.
        let snapshot = store.snapshot
        let burndown = store.burndown
        let boardMismatch = snapshot.map { $0.sprint.boardID != store.selectedBoard } ?? false
        let ready = snapshot != nil && burndown != nil && !boardMismatch
            && !(burndown?.points.isEmpty ?? true) && !(burndown?.points.allSatisfy { $0.scope == 0 } ?? true)
        let sprint = snapshot?.sprint
        let pace = ready ? burndown.flatMap {
            SprintPace.compute($0, start: sprint?.start, end: sprint?.end, closed: sprint?.state == "closed", now: Date(), calendar: .current)
        } : nil
        ManagementCardFrame(title: "Burndown", icon: "chart.xyaxis.line") {
            ChartKey(items: [.init(label: "Por fazer", color: Color(palette.accent), mark: .line),
                             .init(label: "Ideal", color: Color(palette.textTertiary), mark: .dashed),
                             .init(label: "Previsão", color: Color(palette.accent).opacity(0.6), mark: .dashed)])
        } content: {
            if ready, let burndown, let snapshot {
                BurndownChart(result: burndown, end: snapshot.sprint.end, forecast: pace?.forecastLeft)
                    .frame(height: IslandLayout.managementChart(metrics))
            } else {
                ListNote(text: emptyText(burndown: burndown, boardMismatch: boardMismatch))
            }
        } footer: {
            if ready, let burndown {
                BurndownSummaryRow(result: burndown, pace: pace, unit: store.effectiveUnit,
                                   showsPointsWarning: store.effectiveUnit == .points && burndown.showsMissingPointsWarning,
                                   switchToTasks: { store.unit = .tasks })
            }
            if case .error(let message) = store.status { Pill(message, Color(palette.red)) }
        }
    }

    private func emptyText(burndown: BurndownResult?, boardMismatch: Bool) -> String {
        guard let burndown, !boardMismatch else { return ManagementStateMessage.text(for: store) }
        return burndown.memberCount == 0 ? "Sem tasks nesta sprint" : "Sem pontos nesta sprint"
    }
}
