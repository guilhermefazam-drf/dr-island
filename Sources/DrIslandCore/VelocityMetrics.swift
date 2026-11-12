import Foundation

/// Planned against finished, sprint by sprint. Pure: it reuses the burndown of each sprint.
public enum VelocityMetrics {
    public static let defaultSprints = 6

    /// `snapshots` in any order; the result is oldest first, limited to the latest `limit` closed sprints.
    public static func compute(_ snapshots: [SprintSnapshot], unit: MetricUnit, now: Date, calendar: Calendar, limit: Int = defaultSprints) -> VelocityResult {
        let closed = snapshots.filter { $0.sprint.state == "closed" }
            .sorted { ($0.sprint.start ?? .distantPast) < ($1.sprint.start ?? .distantPast) }
            .suffix(limit)
        let sprints = closed.map { snapshot -> VelocitySprint in
            let burndown = Burndown.compute(snapshot, unit: unit, now: now, calendar: calendar)
            let last = burndown.points.last
            let scope = last?.scope ?? 0
            return VelocitySprint(id: snapshot.sprint.id, name: snapshot.sprint.name, planned: burndown.plannedScope,
                                  completed: max(0, scope - (last?.remaining ?? 0)), added: max(0, scope - burndown.plannedScope))
        }
        let average = sprints.isEmpty ? 0 : sprints.map(\.completed).reduce(0, +) / Double(sprints.count)
        return VelocityResult(sprints: sprints, averageCompleted: average)
    }
}
