import Testing
@testable import DrIslandCore

@Suite struct ChartScaleTests {
    @Test func scopeOf33DrawsOnZeroToForty() {
        let scale = ChartScale.nice(maxValue: 33)
        #expect(scale.top == 40)
        #expect(scale.ticks == [0, 20, 40])
    }

    @Test func smallCountsKeepWholeTicks() {
        let scale = ChartScale.nice(maxValue: 6)
        #expect(scale.step == 2)
        #expect(scale.top == 8)
        #expect(scale.ticks.allSatisfy { $0 == $0.rounded() })
    }

    @Test func tinyValuesNeverGoFractional() {
        #expect(ChartScale.nice(maxValue: 1).step == 1)
        #expect(ChartScale.nice(maxValue: 0.2).top == 1)
    }

    @Test func emptyDataGetsAUsableAxis() {
        let scale = ChartScale.nice(maxValue: 0)
        #expect(scale.top > 0)
        #expect(scale.ticks.first == 0)
    }

    @Test func topAlwaysCoversTheData() {
        for value in [3.0, 9, 10, 19, 24, 33, 48, 99, 120, 512] {
            #expect(ChartScale.nice(maxValue: value).top >= value)
        }
    }
}
