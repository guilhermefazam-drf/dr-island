import Foundation
import Testing
@testable import DrIslandCore

@Suite struct SprintSnapshotFileCacheTests {
    private func snapshot(id: Int, state: String) -> SprintSnapshot {
        let sprint = SprintRecord(id: id, name: "Sprint \(id)", boardID: 1, start: Date(timeIntervalSince1970: 1_700_000_000),
                                  end: Date(timeIntervalSince1970: 1_701_000_000), state: state, completedAt: nil)
        let issue = SprintIssue(key: "APP-1", type: "Story", points: 3, status: "Done", statusID: "10", isFlagged: false,
                                created: Date(timeIntervalSince1970: 1_699_000_000), resolved: nil,
                                events: [SprintIssueEvent(date: Date(timeIntervalSince1970: 1_700_500_000), kind: .status, from: "1", to: "10")])
        return SprintSnapshot(sprint: sprint, issues: [issue], statusCategories: ["10": "done"],
                              fetchedAt: Date(timeIntervalSince1970: 1_702_000_000), statusNames: ["10": "Done"])
    }

    private func temporaryCache() -> SprintSnapshotFileCache {
        SprintSnapshotFileCache(directory: FileManager.default.temporaryDirectory.appendingPathComponent("sprint-cache-\(UUID().uuidString)"))
    }

    @Test func closedSprintComesBackTheSame() {
        let cache = temporaryCache()
        let saved = snapshot(id: 42, state: "closed")
        cache.save(saved)
        #expect(cache.load(sprintID: 42) == saved)
    }

    @Test func openSprintIsNeverStored() {
        let cache = temporaryCache()
        cache.save(snapshot(id: 7, state: "active"))
        #expect(cache.load(sprintID: 7) == nil)
    }

    @Test func unknownSprintIsAMiss() {
        #expect(temporaryCache().load(sprintID: 999) == nil)
    }

    @Test func fileNameCarriesTheFormatVersion() {
        #expect(temporaryCache().url(for: 5).lastPathComponent == "v\(SprintSnapshotFileCache.version)-5.json")
    }
}
