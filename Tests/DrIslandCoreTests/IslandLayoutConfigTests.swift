import Testing
@testable import DrIslandCore

@Suite struct IslandLayoutConfigTests {
    @Test func everyBlockAppearsExactlyOnce() {
        for layout in [IslandLayoutConfig.vertical, .twoColumns, .threeColumns] {
            let all = layout.columns.flatMap { $0 }
            #expect(all.count == IslandBlock.allCases.count)
            #expect(Set(all).count == all.count)
        }
    }

    @Test func widthsAndColumnCounts() {
        #expect(IslandLayoutConfig.vertical.width == 400)
        #expect(IslandLayoutConfig.twoColumns.width == 660)
        #expect(IslandLayoutConfig.threeColumns.width == 870)
        #expect(IslandLayoutConfig.maxWidth == 870 + 3 * IslandLayoutConfig.maxExtraColumnWidth)
    }

    @Test func normalizesDuplicatesMissingAndTooManyColumns() {
        let messy = IslandLayoutConfig(columns: [[.jira, .jira], [.claude], [], [.music]])
        #expect(messy.columnCount == 3)
        #expect(messy.columns.flatMap { $0 }.count == IslandBlock.allCases.count)
        #expect(messy.columns[0].first == .jira)
        #expect(IslandLayoutConfig(columns: []).columnCount == 1)
    }

    @Test func movingBetweenColumns() {
        let moved = IslandLayoutConfig.twoColumns.moving(.music, toColumn: 1)
        #expect(moved.column(of: .music) == 1)
        #expect(moved.columns[1].last == .music)
        #expect(!moved.columns[0].contains(.music))
        #expect(IslandLayoutConfig.vertical.moving(.music, toColumn: 5) == .vertical)   // no such column
    }

    @Test func shiftingInsideAColumn() {
        let up = IslandLayoutConfig.vertical.shifting(.jira, by: -1)
        #expect(up.columns[0].prefix(4) == [.briefing, .claude, .jira, .pullRequests])
        #expect(IslandLayoutConfig.vertical.shifting(.briefing, by: -1) == .vertical)   // already first
    }

    @Test func resizingKeepsEveryBlock() {
        let one = IslandLayoutConfig.threeColumns.resized(to: 1)
        #expect(one.columnCount == 1)
        #expect(one.columns[0].count == IslandBlock.allCases.count)
        let three = IslandLayoutConfig.vertical.resized(to: 3)
        #expect(three.columnCount == 3)
        #expect(three.columns[1].isEmpty && three.columns[2].isEmpty)
    }

    @Test func roundTripAndBadInput() {
        let layout = IslandLayoutConfig.threeColumns
        #expect(IslandLayoutConfig.decode(layout.encoded()) == layout)
        #expect(IslandLayoutConfig.decode("junk") == .vertical)
        #expect(IslandLayoutConfig.decode(nil) == .vertical)
        // An unknown block name from a newer version is dropped, and the rest repaired.
        #expect(IslandLayoutConfig.decode(#"{"columns":[["claude","nope"]]}"#).columns[0].count == IslandBlock.allCases.count)
    }
}

@Suite struct IslandLayoutWidthTests {
    @Test func extraWidthScalesWithColumnsAndSurvivesEncoding() {
        let layout = IslandLayoutConfig.twoColumns.withExtraColumnWidth(40)
        #expect(layout.width == 660 + 80)
        #expect(IslandLayoutConfig.decode(layout.encoded()).extraColumnWidth == 40)
        #expect(layout.resized(to: 3).extraColumnWidth == 40)
        #expect(IslandLayoutConfig.decode(#"{"columns":[["claude"]]}"#).extraColumnWidth == 0)
        #expect(IslandLayoutConfig.vertical.withExtraColumnWidth(999).extraColumnWidth == IslandLayoutConfig.maxExtraColumnWidth)
    }

    @Test func oldApprovalsBlockMergesIntoJira() {
        let old = IslandLayoutConfig.decode(#"{"columns":[["claude","jira","music"],["jiraApprovals","alerts"]]}"#)
        #expect(old.columns[0].prefix(3) == [.claude, .jira, .music])
        #expect(old.columns.flatMap { $0 }.filter { $0 == .jira }.count == 1)
        #expect(old.columns.flatMap { $0 }.count == IslandBlock.allCases.count)
        // Only the old approvals block saved: it becomes the Jira card in that place.
        #expect(IslandLayoutConfig.decode(#"{"columns":[["claude"],["jiraApprovals"]]}"#).column(of: .jira) == 1)
    }

    @Test func savedOutOfSprintBlockMovesIntoTheJiraCard() {
        let old = IslandLayoutConfig.decode(#"{"columns":[["claude","jira","outOfSprint","music"]]}"#)
        #expect(old.columns[0].prefix(3) == [.claude, .jira, .music])
        #expect(old.columns.flatMap { $0 }.count == IslandBlock.allCases.count)
    }
}
