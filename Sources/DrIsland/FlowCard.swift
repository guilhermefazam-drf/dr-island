import SwiftUI
import DrIslandCore

/// Where the sprint's work is, how long it stays in each status and what is stuck.
struct FlowCard: View {
    let store: ManagementStore

    var body: some View {
        let snapshot = store.snapshot
        let boardMismatch = snapshot.map { $0.sprint.boardID != store.selectedBoard } ?? false
        VStack(alignment: .leading, spacing: 4) {
            CardTitle(title: "Fluxo", icon: "arrow.triangle.branch")
            if let snapshot, !boardMismatch {
                FlowBody(result: FlowMetrics.compute(snapshot, unit: store.effectiveUnit, now: Date()))
            } else {
                ListNote(text: ManagementStateMessage.text(for: store))
            }
        }
        .frame(maxWidth: .infinity, minHeight: IslandLayout.managementCardContent, maxHeight: IslandLayout.managementCardContent, alignment: .topLeading)
        .blockCard()
    }
}
