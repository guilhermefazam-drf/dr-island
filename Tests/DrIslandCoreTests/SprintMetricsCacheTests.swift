import Testing
import Foundation
@testable import DrIslandCore

@Suite struct SprintMetricsCacheTests {
    @Test func noCacheNeverStores() {
        let sprint = SprintRecord(id: 7, name: "S7", boardID: 1, start: nil, end: nil, state: "closed", completedAt: nil)
        let snapshot = SprintSnapshot(sprint: sprint, issues: [], statusCategories: [:], fetchedAt: Date())
        let cache = NoSprintMetricsCache()
        cache.save(snapshot)
        #expect(cache.load(sprintID: 7) == nil)
    }
}
