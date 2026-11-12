import SwiftUI
import DrIslandCore

/// The status bars and, under them, the tasks worth a look.
struct FlowBody: View {
    let result: FlowResult
    private static let maxRows = 6

    var body: some View {
        if result.rows.isEmpty {
            ListNote(text: "Sem tasks nesta sprint")
        } else {
            let shown = Array(result.rows.prefix(Self.maxRows))
            let largest = shown.map(\.amount).max() ?? 0
            VStack(alignment: .leading, spacing: 0) {
                ForEach(shown) { FlowBarRow(row: $0, largest: largest) }
            }
            if !result.stuck.isEmpty {
                ListRule()
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(result.stuck) { FlowStuckRow(task: $0) }
                }
            }
        }
    }
}
