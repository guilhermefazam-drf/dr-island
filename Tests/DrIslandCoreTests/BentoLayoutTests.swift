import Testing
@testable import DrIslandCore

@Suite struct BentoLayoutTests {
    private let all = Set(BentoLayout.KPI.allCases)

    @Test func styleFallsBackToCamadas() {
        #expect(IslandStyle(stored: nil) == .camadas)
        #expect(IslandStyle(stored: "xpto") == .camadas)
        #expect(IslandStyle(stored: "bento") == .bento)
    }

    @Test func bentoWidths() {
        #expect(IslandLayoutConfig.width(columns: 1, style: .bento) == 400)
        #expect(IslandLayoutConfig.width(columns: 2, style: .bento) == 780)
        #expect(IslandLayoutConfig.width(columns: 3, style: .bento) == 960)
        #expect(IslandLayoutConfig.width(columns: 1, density: .compact, style: .bento) == 340)
        #expect(IslandLayoutConfig.width(columns: 2, density: .compact, style: .bento) == 620)
        #expect(IslandLayoutConfig.width(columns: 3, density: .compact, style: .bento) == 800)
        #expect(IslandLayoutConfig.width(columns: 2, style: .camadas) == 660)
        #expect(IslandLayoutConfig.maxWidth >= 960)
    }

    @Test func kpisPerColumnCount() {
        #expect(BentoLayout.kpis(columns: 1, available: all) == [.claude, .pullRequests, .sprint, .focus])
        #expect(BentoLayout.kpis(columns: 2, available: all) == [.claude, .pullRequests, .sprint, .focus])
        #expect(BentoLayout.kpis(columns: 3, available: all) == [.claude, .pullRequests, .sprint, .focus, .jira, .alerts])
        #expect(BentoLayout.kpis(columns: 2, available: [.claude, .focus]) == [.claude, .focus])
    }

    @Test func kpiRows() {
        #expect(BentoLayout.kpiRows(count: 4, columns: 1) == 2)
        #expect(BentoLayout.kpiRows(count: 4, columns: 2) == 1)
        #expect(BentoLayout.kpiRows(count: 3, columns: 1) == 2)
        #expect(BentoLayout.kpiRows(count: 6, columns: 3) == 1)
        #expect(BentoLayout.kpiRows(count: 0, columns: 2) == 0)
    }

    @Test func blocksShownElsewhereLeaveTheLists() {
        let two = IslandLayoutConfig.twoColumns
        let lists = BentoLayout.listBlocks(two)
        #expect(!lists.contains(.claude)); #expect(!lists.contains(.focus)); #expect(!lists.contains(.music))
        #expect(!lists.contains(.alerts))
        #expect(lists.contains(.pullRequests)); #expect(lists.contains(.history))
        // With three columns the alerts are a column card again.
        #expect(BentoLayout.listBlocks(.threeColumns).contains(.alerts))
    }

    @Test func distributeBalancesAndKeepsOrder() {
        let h: [IslandBlock: Double] = [.pullRequests: 200, .sprint: 300, .jira: 150, .backlog: 100, .history: 80]
        let cols = BentoLayout.distribute([.pullRequests, .sprint, .jira, .backlog, .history], columns: 2, gap: 10) { h[$0]! }
        #expect(cols == [[.pullRequests, .jira, .history], [.sprint, .backlog]])
        #expect(BentoLayout.distribute([.jira], columns: 3, gap: 10) { _ in 1 } == [[.jira], [], []])
        #expect(BentoLayout.distribute([.jira, .sprint], columns: 1, gap: 10) { _ in 1 } == [[.jira, .sprint]])
    }
}
