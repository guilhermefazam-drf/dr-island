import Foundation
import Testing
@testable import DrIslandCore

@Suite struct UsageAlertsTests {
    @Test func forecastBeforeReset() {
        let now = Date()
        let samples = [UsageSample(date: now.addingTimeInterval(-1800), fraction: 0.2), UsageSample(date: now, fraction: 0.4)]
        // 20% per 30 min → 60% left takes 90 min.
        let eta = UsageAlerts.exhaustion(samples: samples, resetsAt: now.addingTimeInterval(3 * 3600), now: now)
        #expect(eta != nil)
        #expect(abs((eta?.timeIntervalSince(now) ?? 0) - 5400) < 1)
    }

    @Test func noForecastWhenResetComesFirstOrTooLittleData() {
        let now = Date()
        let slow = [UsageSample(date: now.addingTimeInterval(-1800), fraction: 0.2), UsageSample(date: now, fraction: 0.4)]
        #expect(UsageAlerts.exhaustion(samples: slow, resetsAt: now.addingTimeInterval(1800), now: now) == nil)
        let short = [UsageSample(date: now.addingTimeInterval(-120), fraction: 0.2), UsageSample(date: now, fraction: 0.4)]
        #expect(UsageAlerts.exhaustion(samples: short, resetsAt: now.addingTimeInterval(7200), now: now) == nil)
        let flat = [UsageSample(date: now.addingTimeInterval(-1800), fraction: 0.4), UsageSample(date: now, fraction: 0.4)]
        #expect(UsageAlerts.exhaustion(samples: flat, resetsAt: now.addingTimeInterval(7200), now: now) == nil)
    }
}
