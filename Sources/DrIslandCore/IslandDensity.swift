import Foundation

/// How much the island packs in: Normal (two-line rows, more air) or Compacto (one-line rows, narrower).
public enum IslandDensity: String, CaseIterable, Codable, Sendable {
    case regular
    case compact

    /// The stored setting, or Normal when it is missing or unknown.
    public init(stored: String?) {
        self = stored.flatMap(IslandDensity.init(rawValue:)) ?? .regular
    }

    public var title: String {
        switch self {
        case .regular: "Normal"
        case .compact: "Compacto"
        }
    }
}
