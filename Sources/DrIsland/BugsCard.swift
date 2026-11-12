import SwiftUI
import DrIslandCore

/// Bugs created against bugs resolved, week by week, with how many are open and how long they take.
struct BugsCard: View {
    let side: ManagementSideData

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CardTitle(title: "Bugs · \(BugFlow.defaultWeeks) semanas", icon: "ladybug")
            if let bugs = side.bugs {
                BugsBody(result: bugs)
            } else {
                ListNote(text: message)
            }
        }
        .frame(maxWidth: .infinity, minHeight: IslandLayout.managementCardContent, maxHeight: IslandLayout.managementCardContent, alignment: .topLeading)
        .blockCard()
    }

    private var message: String {
        switch side.bugsPhase {
        case .error(let text): return text
        case .ok: return "Sem bugs nas últimas semanas"
        case .idle, .loading: return "A carregar…"
        }
    }
}
