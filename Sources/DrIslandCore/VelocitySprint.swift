import Foundation

/// One sprint of the velocity chart.
public struct VelocitySprint: Equatable, Sendable, Identifiable {
    public var id: Int
    public var name: String
    /// What the sprint held when it started, what it finished, and what came in after the start.
    public var planned: Double
    public var completed: Double
    public var added: Double

    /// «#18» out of «SPRINT #18_Clínica», for an axis label; the name itself when it has no number.
    public var shortName: String {
        if let range = name.range(of: "#?[0-9]+", options: .regularExpression) { return String(name[range]).hasPrefix("#") ? String(name[range]) : "#" + name[range] }
        return String(name.prefix(8))
    }

    public init(id: Int, name: String, planned: Double, completed: Double, added: Double) {
        self.id = id; self.name = name; self.planned = planned; self.completed = completed; self.added = added
    }
}
