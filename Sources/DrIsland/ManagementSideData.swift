import Foundation
import Observation
import DrIslandCore

/// What the bugs and velocity charts need beyond the selected sprint: the project's bugs and the closed sprints of the board.
/// Closed sprints never change, so they are read once per session. Jira is read-only.
@MainActor
@Observable
final class ManagementSideData {
    enum Phase: Equatable {
        case idle, loading, ok, error(String)
    }

    private(set) var bugs: BugResult?
    private(set) var bugsPhase: Phase = .idle
    private(set) var velocitySnapshots: [SprintSnapshot] = []
    private(set) var velocityPhase: Phase = .idle

    @ObservationIgnored private let client = JiraClient()
    @ObservationIgnored private var closedSnapshots: [Int: SprintSnapshot] = [:]
    @ObservationIgnored private var bugsGeneration = 0
    @ObservationIgnored private var velocityGeneration = 0
    @ObservationIgnored private var bugsProject: String?

    /// `DR_ISLAND_FAKE_MANAGEMENT`: made-up bugs and sprints instead of Jira.
    func loadDemo() {
        bugs = ManagementDemo.bugs()
        bugsPhase = .ok
        velocitySnapshots = ManagementDemo.closedSnapshots()
        velocityPhase = .ok
    }

    /// Planned against finished for the closed sprints read so far.
    func velocity(unit: MetricUnit) -> VelocityResult {
        VelocityMetrics.compute(velocitySnapshots, unit: unit, now: Date(), calendar: .current)
    }

    func loadBugs(config: JiraConfig, project: String?) {
        guard let project else { bugs = nil; bugsPhase = .idle; bugsProject = nil; return }
        if project != bugsProject { bugs = nil }   // another project's bugs must not stay under this one's name
        bugsProject = project
        bugsGeneration += 1
        let mine = bugsGeneration
        bugsPhase = .loading
        Task { [weak self] in
            guard let self else { return }
            do {
                let read = try await client.fetchBugs(config, project: project)
                guard mine == bugsGeneration else { return }
                bugs = BugFlow.compute(read.recent, openNow: read.openCount, openIsCapped: read.openCapped, now: Date(), calendar: .current)
                bugsPhase = .ok
            } catch {
                guard mine == bugsGeneration else { return }
                ErrorLog.record("Jira", "Gestão (bugs): \(error)")
                bugsPhase = .error("Não foi possível ler os bugs.")
            }
        }
    }

    func loadVelocity(config: JiraConfig, sprints: [SprintRecord], sprintField: String?, points: (id: String, name: String)?) {
        velocityGeneration += 1
        let mine = velocityGeneration
        let closed = Array(sprints.filter { $0.state == "closed" }.prefix(VelocityMetrics.defaultSprints))
        velocitySnapshots = closed.compactMap { closedSnapshots[$0.id] }
        guard let sprintField, !closed.isEmpty else { velocityPhase = closed.isEmpty ? .ok : .idle; return }
        velocityPhase = closed.allSatisfy({ closedSnapshots[$0.id] != nil }) ? .ok : .loading
        guard velocityPhase == .loading else { return }
        Task { [weak self] in
            guard let self else { return }
            for sprint in closed where closedSnapshots[sprint.id] == nil {
                do {
                    let snapshot = try await client.fetchSprintSnapshot(config, sprint: sprint, sprintField: sprintField, points: points)
                    guard mine == velocityGeneration else { return }
                    closedSnapshots[sprint.id] = snapshot
                    velocitySnapshots = closed.compactMap { self.closedSnapshots[$0.id] }   // the chart fills in as they arrive
                } catch {
                    guard mine == velocityGeneration else { return }
                    ErrorLog.record("Jira", "Gestão (velocity): \(error)")
                    velocityPhase = .error("Não foi possível ler as sprints anteriores.")
                    return
                }
            }
            guard mine == velocityGeneration else { return }
            velocityPhase = .ok
        }
    }
}
