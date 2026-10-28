import Testing
@testable import DrIslandCore

@Suite struct IslandEffectTests {
    @Test func decodesStoredValue() {
        #expect(IslandEffect(stored: "genie") == .genie)
        #expect(IslandEffect(stored: "slit") == .slit)
    }

    @Test func unknownOrMissingFallsBackToDefault() {
        #expect(IslandEffect(stored: nil) == .spring)
        #expect(IslandEffect(stored: "") == .spring)
        #expect(IslandEffect(stored: "nope") == .spring)
        // Removed effects stored by an earlier version.
        #expect(IslandEffect(stored: "curtain") == .spring)
        #expect(IslandEffect(stored: "zoom") == .spring)
    }

    @Test func everyEffectRoundTripsAndHasText() {
        #expect(IslandEffect.allCases.count == 6)
        for effect in IslandEffect.allCases {
            #expect(IslandEffect(stored: effect.rawValue) == effect)
            #expect(!effect.title.isEmpty && !effect.summary.isEmpty)
        }
    }
}
