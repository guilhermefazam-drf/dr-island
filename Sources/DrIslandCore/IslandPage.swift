import Foundation

/// The island's two pages: today's overview and the manager's «Gestão» page.
public enum IslandPage: Int, CaseIterable, Sendable {
    case overview, management

    public var title: String {
        switch self {
        case .overview: return "Resumo"
        case .management: return "Gestão"
        }
    }
}
