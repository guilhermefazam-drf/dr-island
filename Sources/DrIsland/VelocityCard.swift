import SwiftUI
import DrIslandCore

/// Planned against finished over the last closed sprints of the board.
struct VelocityCard: View {
    let store: ManagementStore

    var body: some View {
        let result = store.side.velocity(unit: store.effectiveUnit)
        VStack(alignment: .leading, spacing: 6) {
            CardTitle(title: "Velocity", icon: "speedometer")
            if result.sprints.isEmpty {
                ListNote(text: message)
            } else {
                VelocityChart(result: result).frame(height: IslandLayout.managementChart)
                VelocityLegend()
                HStack(spacing: 6) {
                    RowTag("média \(result.averageCompleted.formatted(.number.precision(.fractionLength(0...1)))) \(store.effectiveUnit == .points ? "pontos" : "tasks")", Brand.green)
                    RowTag("\(result.sprints.count) sprints", .gray)
                    if store.side.velocityPhase == .loading { RowTag("a ler mais…", .gray) }
                    Spacer(minLength: 0)
                }
                .frame(height: IslandLayout.managementSummary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: IslandLayout.managementCardContent, maxHeight: IslandLayout.managementCardContent, alignment: .topLeading)
        .blockCard()
    }

    private var message: String {
        switch store.side.velocityPhase {
        case .error(let text): return text
        case .ok: return "Sem sprints fechadas neste board"
        case .idle, .loading: return "A carregar…"
        }
    }
}
