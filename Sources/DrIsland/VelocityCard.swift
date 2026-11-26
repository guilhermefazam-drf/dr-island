import SwiftUI
import DrIslandCore

/// Planned against finished over the last closed sprints of the board.
struct VelocityCard: View {
    @Environment(\.islandPalette) private var palette
    @Environment(\.islandMetrics) private var metrics
    let store: ManagementStore

    var body: some View {
        let result = store.side.velocity(unit: store.effectiveUnit)
        let unit = store.effectiveUnit == .points ? "pts" : "tasks"
        ManagementCardFrame(title: "Velocity", icon: "speedometer") {
            ChartKey(items: [.init(label: "Planeado", color: Color(palette.text).opacity(0.18)),
                             .init(label: "Concluído", color: Color(palette.accent))])
        } content: {
            if result.sprints.isEmpty {
                ListNote(text: message)
            } else {
                VelocityChart(result: result).frame(height: IslandLayout.managementChart(metrics))
            }
        } footer: {
            if !result.sprints.isEmpty {
                Pill("média \(ManagementKPIs.format(result.averageCompleted.rounded())) \(unit)", Color(palette.green))
                Pill("\(result.sprints.count) sprints", Color(palette.neutral))
                let planned = result.sprints.map(\.planned).reduce(0, +)
                if planned > 0 {
                    Pill("cumpre \(Int((result.sprints.map(\.completed).reduce(0, +) / planned * 100).rounded()))% do plano", Color(palette.neutral))
                }
                if store.side.velocityPhase == .loading { Pill("a ler mais…", Color(palette.neutral)) }
            }
        }
    }

    private var message: String {
        switch store.side.velocityPhase {
        case .error(let text): return text
        case .ok: return "Sem sprints fechadas neste board"
        case .idle, .loading: return "A carregar…"
        }
    }
}
