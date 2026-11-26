import SwiftUI
import DrIslandCore

/// Bugs created against bugs resolved, week by week, with how many are open and how long they take.
struct BugsCard: View {
    @Environment(\.islandPalette) private var palette
    @Environment(\.islandMetrics) private var metrics
    let side: ManagementSideData

    var body: some View {
        ManagementCardFrame(title: "Bugs · \(BugFlow.defaultWeeks) semanas", icon: "ladybug") {
            ChartKey(items: [.init(label: "Criados", color: BugsChart.createdColor(palette)),
                             .init(label: "Resolvidos", color: BugsChart.resolvedColor(palette))])
        } content: {
            if let bugs = side.bugs {
                BugsChart(weeks: bugs.weeks).frame(height: IslandLayout.managementChart(metrics))
            } else {
                ListNote(text: message)
            }
        } footer: {
            if let bugs = side.bugs {
                let created = bugs.weeks.map(\.created).reduce(0, +), resolved = bugs.weeks.map(\.resolved).reduce(0, +)
                Pill("\(bugs.openIsCapped ? "\(bugs.openNow)+" : "\(bugs.openNow)") abertos", bugs.openNow > 0 ? Color(palette.red) : Color(palette.neutral))
                Pill("\(created) criados · \(resolved) resolvidos", Color(palette.neutral))
                if let days = bugs.medianDaysToResolve {
                    Pill("mediana \(days.formatted(.number.precision(.fractionLength(0...1)))) d", Color(palette.accent))
                }
            }
        }
    }

    private var message: String {
        switch side.bugsPhase {
        case .error(let text): return text
        case .ok: return "Sem bugs nas últimas semanas"
        case .idle, .loading: return "A carregar…"
        }
    }
}
