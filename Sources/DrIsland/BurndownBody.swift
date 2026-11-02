import SwiftUI
import DrIslandCore

/// The chart, its legend and the summary tags; the card shows a note instead when there is nothing to draw.
struct BurndownBody: View {
    let store: ManagementStore
    let snapshot: SprintSnapshot
    let result: BurndownResult

    var body: some View {
        if result.points.isEmpty || result.points.allSatisfy({ $0.scope == 0 }) {
            ListNote(text: result.memberCount == 0 ? "Sem tasks nesta sprint" : "Sem pontos nesta sprint")
        } else {
            BurndownChart(result: result).frame(height: IslandLayout.managementChart)
            BurndownLegend()
            BurndownSummaryRow(result: result, deadline: deadline, showsPointsWarning: showsPointsWarning, switchToTasks: switchToTasks)
            if case .error(let message) = store.status { ListNote(text: message, small: true) }
        }
    }

    private var deadline: BurndownSummary.Deadline {
        BurndownSummary.deadline(result, closed: snapshot.sprint.state == "closed", sprintEnd: snapshot.sprint.end, now: Date(), calendar: .current)
    }

    private var showsPointsWarning: Bool { store.effectiveUnit == .points && result.showsMissingPointsWarning }

    private func switchToTasks() { store.unit = .tasks }
}
