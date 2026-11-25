import Foundation

/// How the expanded island is composed. Camadas: the user's columns of cards. Bento: a row of big numbers on top,
/// the lists in balanced columns under it, recent events in a strip and the music in the dock.
public enum IslandStyle: String, CaseIterable, Codable, Sendable {
    case camadas
    case bento

    /// The stored setting, or Camadas when it is missing or unknown.
    public init(stored: String?) {
        self = stored.flatMap(IslandStyle.init(rawValue:)) ?? .camadas
    }

    public var title: String {
        switch self {
        case .camadas: "Camadas"
        case .bento: "Bento"
        }
    }
}
