import Testing
import Foundation
@testable import DrIslandCore

@Suite struct UsageParsingTests {
    private var sample = """
    {"five_hour":{"utilization":46.0,"resets_at":"2026-10-17T14:50:00.188549+00:00","limit_dollars":null},
     "seven_day":{"utilization":57.0,"resets_at":"2026-10-20T00:00:00.188573+00:00"},
     "seven_day_opus":null,"extra_usage":{"is_enabled":false}}
    """

    @Test func parsesSessionAndWeekly() throws {
        let usage = try UsageParser.parse(Data(sample.utf8))
        #expect(usage.session?.utilization == 46.0)
        #expect(usage.weekly?.utilization == 57.0)
        #expect(abs((usage.session?.fraction ?? 0) - (0.46)) <= 0.0001)
        let expected = ISO8601DateFormatter().date(from: "2026-10-17T14:50:00Z")!
        #expect(abs((usage.session?.resetsAt?.timeIntervalSince1970 ?? 0) - (expected.timeIntervalSince1970)) <= 1)
    }

    @Test func missingWindowsAreNil() throws {
        let usage = try UsageParser.parse(Data(#"{"five_hour":null}"#.utf8))
        #expect(usage.session == nil)
        #expect(usage.weekly == nil)
    }

    @Test func fractionIsClamped() {
        #expect(UsageWindow(utilization: 140, resetsAt: nil).fraction == 1)
        #expect(UsageWindow(utilization: -5, resetsAt: nil).fraction == 0)
    }

    @Test func invalidJSONThrows() {
        #expect(throws: Error.self) { try UsageParser.parse(Data("[]".utf8)) }
    }

    @Test func dateWithoutFraction() {
        #expect(UsageParser.parseDate("2026-10-17T14:50:00+00:00") != nil)
        #expect(UsageParser.parseDate("2026-10-17T14:50:00.5+00:00") != nil)
    }
}

@Suite struct CredentialsTests {
    @Test func parsesPlainJSON() throws {
        let json = #"{"claudeAiOauth":{"accessToken":"tok-123","expiresAt":1}}"#
        #expect(try ClaudeCredentials.parseAccessToken(from: Data(json.utf8)) == "tok-123")
    }

    @Test func parsesHexEncodedJSON() throws {
        let json = #"{"claudeAiOauth":{"accessToken":"tok-abc"}}"#
        let hex = json.utf8.map { String(format: "%02x", $0) }.joined()
        #expect(try ClaudeCredentials.parseAccessToken(from: Data(hex.utf8)) == "tok-abc")
    }

    @Test func missingTokenThrows() {
        #expect(throws: Error.self) { try ClaudeCredentials.parseAccessToken(from: Data("{}".utf8)) }
    }
}

@Suite struct GeometryTests {
    @Test func notchMetricsFromAuxAreas() {
        let m = NotchGeometry.metrics(screenWidth: 1728, safeAreaTop: 32, auxLeftWidth: 772, auxRightWidth: 772, menuBarHeight: 32)
        #expect(m == NotchMetrics(width: 184, height: 32, hasNotch: true))
        // real MacBook: asymmetric aux areas shift the notch off-centre
        let real = NotchGeometry.metrics(screenWidth: 1800, safeAreaTop: 38, auxLeftWidth: 791, auxRightWidth: 788, menuBarHeight: 39)
        #expect(real.width == 221 && real.height == 38 && real.centerOffset == 1.5)
    }

    @Test func fallbackWithoutNotch() {
        let m = NotchGeometry.metrics(screenWidth: 2560, safeAreaTop: 0, auxLeftWidth: nil, auxRightWidth: nil, menuBarHeight: 24)
        #expect(!m.hasNotch)
        #expect(m.width == NotchGeometry.fallbackPillWidth)
        #expect(m.height == 24)
    }

    @Test func topCenteredFrameHonoursOffset() {
        let frame = NotchGeometry.topCenteredFrame(screenFrame: CGRect(x: 0, y: 0, width: 1000, height: 800), size: CGSize(width: 200, height: 50), centerOffset: 2)
        #expect(frame.midX == 502)
    }

    @Test func topCenteredFrame() {
        let frame = NotchGeometry.topCenteredFrame(screenFrame: CGRect(x: 100, y: 0, width: 1000, height: 800), size: CGSize(width: 400, height: 150))
        #expect(frame == CGRect(x: 400, y: 650, width: 400, height: 150))
    }
}

@Suite struct LevelAndTimeTests {
    @Test func levels() {
        #expect(UsageLevel.level(forFraction: 0.59, amber: 60, red: 85) == .normal)
        #expect(UsageLevel.level(forFraction: 0.60, amber: 60, red: 85) == .warning)
        #expect(UsageLevel.level(forFraction: 0.85, amber: 60, red: 85) == .critical)
        // red below amber is treated as equal to amber
        #expect(UsageLevel.level(forFraction: 0.70, amber: 80, red: 50) == .normal)
        #expect(UsageLevel.level(forFraction: 0.80, amber: 80, red: 50) == .critical)
    }

    @Test func remainingTime() {
        let now = Date(timeIntervalSince1970: 0)
        #expect(RemainingTime.string(until: now.addingTimeInterval(-5), now: now) == "agora")
        #expect(RemainingTime.string(until: now.addingTimeInterval(45 * 60), now: now) == "45m")
        #expect(RemainingTime.string(until: now.addingTimeInterval(134 * 60), now: now) == "2h 14m")
        #expect(RemainingTime.string(until: now.addingTimeInterval(3 * 24 * 3600 + 5 * 3600), now: now) == "3d 5h")
    }
}
