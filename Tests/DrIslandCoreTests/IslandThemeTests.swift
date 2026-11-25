import Testing
@testable import DrIslandCore

@Suite struct IslandThemeTests {
    @Test func unknownStoredValueFallsBackToGrafite() {
        #expect(IslandTheme(stored: nil) == .grafite)
        #expect(IslandTheme(stored: "xpto") == .grafite)
        #expect(IslandTheme(stored: "meia-noite") == .meiaNoite)
    }

    @Test func grafiteMatchesTodaysColours() {
        let p = IslandTheme.grafite.palette
        #expect(p.base == [ThemeColor(0x000000)])
        #expect(p.surface == ThemeColor(0xFFFFFF, alpha: 0.055))
        #expect(p.accent == ThemeColor(0x00A6E5))
        #expect(p.green == ThemeColor(0x28C840))
        #expect(p.amber == ThemeColor(0xFEBC2E))
        #expect(p.red == ThemeColor(0xFF5F57))
        #expect(p.isLight == false)
    }

    @Test func everyThemeIsReadable() {
        for theme in IslandTheme.allCases {
            let p = theme.palette
            let card = p.surface.over(p.base.last!)
            #expect(p.text.contrast(with: card) >= 4.5, "\(theme) text")
            #expect(p.textSecondary.contrast(with: card) >= 3, "\(theme) secondary")
        }
    }

    @Test func sourcesHaveTheirColour() {
        let p = IslandTheme.aurora.palette
        #expect(p.source(.claude) == p.orange)
        #expect(p.source(.pullRequests) == p.purple)
        #expect(p.source(.sprint) == p.accent)
        #expect(p.source(.jira) == p.accent)
        #expect(p.source(.backlog) == p.accent)
        #expect(p.source(.focus) == p.green)
        #expect(p.source(.music) == p.pink)
        #expect(p.source(.alerts) == p.amber)
        #expect(p.source(.briefing) == p.amber)
    }

    @Test func onlyClaroIsLight() {
        #expect(IslandTheme.allCases.filter { $0.palette.isLight } == [.claro])
        #expect(IslandTheme.claro.palette.collar == ThemeColor(0x000000))
    }

    @Test func contrastIsTheWCAGRatio() {
        #expect(abs(ThemeColor(0x000000).contrast(with: ThemeColor(0xFFFFFF)) - 21) < 0.01)
        #expect(ThemeColor(0x777777).contrast(with: ThemeColor(0x777777)) == 1)
    }
}
