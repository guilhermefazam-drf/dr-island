/// How the island appears and disappears. Stored in UserDefaults by `rawValue`.
public enum IslandEffect: String, CaseIterable, Sendable {
    case spring, genie, drop, dissolve, hinge, slit

    public static let `default`: IslandEffect = .spring

    /// Unknown or missing values (an older or hand-edited preference) fall back to the default.
    public init(stored: String?) {
        self = stored.flatMap(IslandEffect.init(rawValue:)) ?? .default
    }

    public var title: String {
        switch self {
        case .spring: return "Mola"
        case .genie: return "Génio (lamp)"
        case .drop: return "Gota"
        case .dissolve: return "Dissolver"
        case .hinge: return "Dobradiça"
        case .slit: return "Fenda"
        }
    }

    public var summary: String {
        switch self {
        case .spring: return "Cresce com elasticidade a partir do notch."
        case .genie: return "Funil como o efeito lamp do Mac: sai e é sugada pelo notch."
        case .drop: return "Estica na vertical como uma gota e só depois alarga."
        case .dissolve: return "Muda de tamanho sem overshoot; o conteúdo surge do desfoque."
        case .hinge: return "Roda em 3D à volta da aresta de cima."
        case .slit: return "Abre primeiro em largura e depois em altura."
        }
    }
}
