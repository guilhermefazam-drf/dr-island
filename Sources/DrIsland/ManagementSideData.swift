import Foundation
import Observation
import DrIslandCore

/// What the bugs and velocity charts need beyond the selected sprint: the project's bugs and the closed sprints of the board.
/// Closed sprints never change, so they are read once and kept on disk. Jira is read-only.
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
    @ObservationIgnored private let cache: SprintMetricsCache
    /// Closed sprints read at the same time (each also reads a few changelogs at once inside).
    private static let sprintConcurrency = 2

    init(cache: SprintMetricsCache = NoSprintMetricsCache()) {
        self.cache = cache
    }
    @ObservationIgnored private var closedSnapshots: [Int: SprintSnapshot] = [:]
    @ObservationIgnored private var bugsGeneration = 0
    @ObservationIgnored private var velocityGeneration = 0
    @ObservationIgnored private var bugsProject: String?
    @ObservationIgnored private var bugsReadAt: Date?
    /// Moving between sprints of one project reuses its bugs for this long instead of reading them again.
    private static let bugsFreshFor: TimeInterval = 300

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
        if project == bugsProject, bugsPhase == .ok, let readAt = bugsReadAt, Date().timeIntervalSince(readAt) < Self.bugsFreshFor { return }
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
                bugsReadAt = Date()
            } catch {
                guard mine == bugsGeneration else { return }
                ErrorLog.record("Jira", "Gestão (bugs): \(error)")
                bugsPhase = .error("Não foi possível ler os bugs.")
            }
        }
    }

    func loadVelocity(config: JiraConfig, sprints: [SprintRecord], sprintField: String?, points: (id: String, name: String)?,
                      statuses: (categories: [String: String], names: [String: String])? = nil) {
        velocityGeneration += 1
        let mine = velocityGeneration
        let closed = Array(sprints.filter { $0.state == "closed" }.prefix(VelocityMetrics.defaultSprints))
        // What earlier openings left on disk shows at once.
        for sprint in closed where closedSnapshots[sprint.id] == nil {
            if let saved = cache.load(sprintID: sprint.id) { closedSnapshots[sprint.id] = saved }
        }
        velocitySnapshots = closed.compactMap { closedSnapshots[$0.id] }
        guard let sprintField, !closed.isEmpty else { velocityPhase = closed.isEmpty ? .ok : .idle; return }
        let missing = closed.filter { closedSnapshots[$0.id] == nil }
        velocityPhase = missing.isEmpty ? .ok : .loading
        guard !missing.isEmpty else { return }
        let client = self.client
        Task { [weak self] in
            do {
                try await withThrowingTaskGroup(of: SprintSnapshot.self) { group in
                    var pending = missing[...]
                    func addNext() {
                        guard let sprint = pending.popFirst() else { return }
                        group.addTask { try await client.fetchSprintSnapshot(config, sprint: sprint, sprintField: sprintField, points: points, statuses: statuses) }
                    }
                    for _ in 0..<Self.sprintConcurrency { addNext() }
                    while let snapshot = try await group.next() {
                        guard let self, mine == self.velocityGeneration else { group.cancelAll(); return }
                        self.closedSnapshots[snapshot.sprint.id] = snapshot
                        self.cache.save(snapshot)
                        self.velocitySnapshots = closed.compactMap { self.closedSnapshots[$0.id] }   // the chart fills in as they arrive
                        addNext()
                    }
                }
                guard let self, mine == self.velocityGeneration else { return }
                self.velocityPhase = .ok
            } catch {
                guard let self, mine == self.velocityGeneration else { return }
                ErrorLog.record("Jira", "Gestão (velocity): \(error)")
                self.velocityPhase = .error("Não foi possível ler as sprints anteriores.")
            }
        }
    }
}
