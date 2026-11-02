import Foundation

/// The numbers behind the velocity chart, oldest sprint first.
public struct VelocityResult: Equatable, Sendable {
    public var sprints: [VelocitySprint]
    /// Mean of what the sprints completed; 0 with none.
    public var averageCompleted: Double

    public init(sprints: [VelocitySprint], averageCompleted: Double) {
        self.sprints = sprints; self.averageCompleted = averageCompleted
    }
}
