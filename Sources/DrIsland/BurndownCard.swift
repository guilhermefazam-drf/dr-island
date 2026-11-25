import SwiftUI
import DrIslandCore

/// The burndown of the selected sprint on a card in the island's style.
struct BurndownCard: View {
    @Environment(\.islandMetrics) private var metrics
    let store: ManagementStore

    var body: some View {
        // `burndown` recomputes on every read (it uses `Date()`): read it once per render.
        let snapshot = store.snapshot
        let burndown = store.burndown
        let boardMismatch = snapshot.map { $0.sprint.boardID != store.selectedBoard } ?? false
        VStack(alignment: .leading, spacing: 6) {
            CardTitle(title: snapshot.map { "Burndown · \($0.sprint.name)" } ?? "Burndown", icon: "chart.xyaxis.line")
            if let snapshot, let burndown, !boardMismatch {
                BurndownBody(store: store, snapshot: snapshot, result: burndown)
            } else {
                ListNote(text: ManagementStateMessage.text(for: store))
            }
        }
        .frame(maxWidth: .infinity, minHeight: IslandLayout.managementCardContent(metrics), maxHeight: IslandLayout.managementCardContent(metrics), alignment: .topLeading)
        .blockCard()
    }
}
