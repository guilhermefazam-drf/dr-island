import Foundation

/// What the «Gestão» card says when there is no chart to draw (loading, an error, nothing to show).
@MainActor
enum ManagementStateMessage {
    static func text(for store: ManagementStore) -> String {
        switch store.status {
        case .idle, .loading: return "A carregar…"
        case .error(let message): return message
        case .ok:
            if store.boards.isEmpty { return "Sem boards" }
            if store.sprints.isEmpty { return "Sem sprints neste board" }
            return "A carregar…"
        }
    }
}
