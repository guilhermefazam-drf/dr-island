import Testing
@testable import DrIslandCore

@Suite struct IslandMetricsTests {
    @Test func regularValues() {
        let m = IslandMetrics.forDensity(.regular)
        #expect(m == .regular)
        #expect(m.cardPadding == 14); #expect(m.cardGap == 12); #expect(m.cardRadius == 18)
        #expect(m.rowHeight == 34); #expect(m.rowHasMeta); #expect(m.cardHeader == 26); #expect(m.tile == 24)
        #expect(m.titleSize == 13); #expect(m.bodySize == 13); #expect(m.metaSize == 11.5)
        #expect(m.ringSize == 84); #expect(m.dockIcon == 30)
    }

    @Test func compactValues() {
        let m = IslandMetrics.forDensity(.compact)
        #expect(m == .compact)
        #expect(m.cardPadding == 9); #expect(m.cardGap == 8); #expect(m.cardRadius == 12)
        #expect(m.rowHeight == 22); #expect(!m.rowHasMeta); #expect(m.cardHeader == 20); #expect(m.tile == 18)
        #expect(m.titleSize == 11.5); #expect(m.bodySize == 11.5); #expect(m.metaSize == 10.5)
        #expect(m.ringSize == 52); #expect(m.dockIcon == 22)
        #expect(m.listHeader == 16); #expect(m.listRule == 9); #expect(m.sectionSpacing == 8)
    }

    @Test func cardAddsPaddingOnBothSides() {
        #expect(IslandMetrics.regular.card(100) == 128)
        #expect(IslandMetrics.compact.card(100) == 118)
    }

    @Test func emptyListSectionTakesNoRoom() {
        #expect(IslandMetrics.regular.listSection(rows: 0) == 0)
        #expect(IslandMetrics.regular.listSection(rows: 3) == 20 + 2 + 3 * 34)
    }

    @Test func listCardWithOneUntitledList() {
        let m = IslandMetrics.regular
        #expect(m.listCard(rows: 0) == 28 + 26)
        #expect(m.listCard(rows: 4) == 28 + 26 + 4 * 34)
    }

    @Test func listCardWithTitledListsSkipsEmptyOnesAndRulesBetween() {
        let m = IslandMetrics.regular
        // Two non-empty lists: header, both sections and one rule.
        #expect(m.listCard(sections: [2, 3]) == 28 + 26 + (22 + 68) + (22 + 102) + 13)
        // An empty list adds neither a section nor a rule.
        #expect(m.listCard(sections: [2, 0]) == m.listCard(sections: [2]))
        #expect(m.listCard(sections: [0, 0]) == m.card(26))
    }

    @Test func compactNeverTallerThanToday() {
        let c = IslandMetrics.forDensity(.compact)
        for rows in 0...10 {
            let today = 20.0 + (rows == 0 ? 0 : 20 + 2 + Double(rows) * 25) + 20   // today's one-list card
            #expect(c.listCard(sections: [rows]) <= today, "\(rows) rows, titled")
            #expect(c.listCard(rows: rows) <= today, "\(rows) rows")
        }
    }

    @Test func densityFallsBackToNormal() {
        #expect(IslandDensity(stored: nil) == .regular)
        #expect(IslandDensity(stored: "xpto") == .regular)
        #expect(IslandDensity(stored: "compact") == .compact)
        #expect(IslandDensity.regular.title == "Normal")
        #expect(IslandDensity.compact.title == "Compacto")
    }
}
