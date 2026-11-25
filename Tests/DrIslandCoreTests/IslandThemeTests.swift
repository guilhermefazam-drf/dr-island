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

    @Test func grafiteInfoAndNeutralTokens() {
        let p = IslandTheme.grafite.palette
        #expect(p.info == ThemeColor(0x5C9EFF))
        #expect(p.neutral == ThemeColor(0x8E8E93))
    }

    @Test func increasedContrastRaisesSecondaryText() {
        for theme in IslandTheme.allCases {
            let p = theme.palette
            let a = p.adjusted(increaseContrast: true, reduceTransparency: false)
            let card = p.surface.over(p.base.last!)
            let adjustedCard = a.surface.over(a.base.last!)
            #expect(a.textSecondary.contrast(with: adjustedCard) > p.textSecondary.contrast(with: card), "\(theme)")
            #expect(a.border.a >= p.border.a, "\(theme)")
        }
    }

    @Test func reducedTransparencyMakesSurfacesOpaque() {
        for theme in IslandTheme.allCases {
            let p = theme.palette
            let a = p.adjusted(increaseContrast: false, reduceTransparency: true)
            #expect(a.surface.a == 1, "\(theme)")
            #expect(a.surfaceRaised.a == 1, "\(theme)")
            #expect(a.surface == p.surface.over(p.base.last!), "\(theme)")
        }
    }

    @Test func noSettingsLeavesThePaletteUnchanged() {
        for theme in IslandTheme.allCases {
            #expect(theme.palette.adjusted(increaseContrast: false, reduceTransparency: false) == theme.palette)
        }
    }

    @Test func mixedAndWithAlpha() {
        let black = ThemeColor(0x000000), white = ThemeColor(0xFFFFFF)
        #expect(black.mixed(with: white, amount: 0) == black)
        #expect(black.mixed(with: white, amount: 1) == white)
        #expect(black.mixed(with: white, amount: 0.5).r == 0.5)
        #expect(black.mixed(with: white, amount: 2) == white)
        #expect(white.withAlpha(0.3).a == 0.3)
        #expect(white.withAlpha(1.5).a == 1)
    }
}
