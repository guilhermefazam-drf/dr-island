import SwiftUI
import DrIslandCore

/// Where the sprint's work is (a segmented bar by status group), how long it stays in each and what is stuck.
struct FlowCard: View {
    @Environment(\.islandPalette) private var palette
    let store: ManagementStore

    var body: some View {
        let snapshot = store.snapshot
        let boardMismatch = snapshot.map { $0.sprint.boardID != store.selectedBoard } ?? false
        let result = snapshot.flatMap { boardMismatch ? nil : FlowMetrics.compute($0, unit: store.effectiveUnit, now: Date()) }
        let unit = store.effectiveUnit == .points ? "pts" : "tasks"
        ManagementCardFrame(title: "Fluxo", icon: "arrow.triangle.branch") {
            if let result, !result.rows.isEmpty {
                Text("\(ManagementKPIs.format(result.rows.map(\.amount).reduce(0, +))) \(unit)").monospacedDigit()
            }
        } content: {
            if let result {
                FlowBody(result: result, unit: unit)
            } else {
                ListNote(text: ManagementStateMessage.text(for: store))
            }
        }
    }
}
