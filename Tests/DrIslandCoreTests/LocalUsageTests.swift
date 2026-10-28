import Testing
import Foundation
@testable import DrIslandCore

@Suite struct LocalUsageTests {
    private func date(_ iso: String) -> Date { LogLineParser.parseTimestamp(iso)! }

    @Test func parsesTimestamps() {
        #expect(LogLineParser.parseTimestamp("1970-01-01T00:00:00Z")?.timeIntervalSince1970 == 0)
        #expect(LogLineParser.parseTimestamp("2026-10-17T10:37:59.007Z")?.timeIntervalSince1970 == 1_792_233_479.007)
        #expect(LogLineParser.parseTimestamp("2024-02-29T23:59:59Z")?.timeIntervalSince1970 == 1_709_251_199)
        #expect(LogLineParser.parseTimestamp("2026-10-17T10:37:59+01:00") == nil)
        #expect(LogLineParser.parseTimestamp("garbage") == nil)
    }

    @Test func timestampMatchesFoundation() {
        let formatter = ISO8601DateFormatter()
        for text in ["2000-03-01T00:00:00Z", "2026-12-31T23:59:59Z", "2025-01-01T12:30:15Z"] {
            #expect(LogLineParser.parseTimestamp(text) == formatter.date(from: text))
        }
    }

    @Test func parsesAssistantLine() {
        let line = #"{"type":"assistant","timestamp":"2026-10-17T10:00:00.000Z","requestId":"req_1","message":{"id":"msg_A","content":[{"type":"text","text":"has \"usage\":{ inside"}],"usage":{"input_tokens":2,"cache_creation_input_tokens":100,"cache_read_input_tokens":5000,"output_tokens":10,"iterations":[{"input_tokens":2,"output_tokens":10}]}}}"#
        let entry = LogLineParser.parse(line: Data(line.utf8))
        #expect(entry?.tokens == 112)               // input + output + cache creation, not cache reads
        #expect(entry?.key == "msg_A|req_1")
    }

    @Test func ignoresLinesWithoutUsage() {
        #expect(LogLineParser.parse(line: Data(#"{"type":"user","timestamp":"2026-10-17T10:00:00Z"}"#.utf8)) == nil)
    }

    @Test func fileParsingHonoursCutoff() {
        let old = #"{"timestamp":"2026-01-01T00:00:00Z","requestId":"r0","message":{"id":"msg_0","usage":{"input_tokens":5,"output_tokens":5}}}"#
        let new = #"{"timestamp":"2026-10-17T00:00:00Z","requestId":"r1","message":{"id":"msg_1","usage":{"input_tokens":5,"output_tokens":5}}}"#
        let data = Data((old + "\n" + new + "\nnot json\n").utf8)
        let entries = LogLineParser.parse(file: data, since: date("2026-06-01T00:00:00Z"))
        #expect(entries.map(\.key) == ["msg_1|r1"])
    }

    @Test func blocksDedupeAndSplitBy5Hours() {
        let e = { (iso: String, tokens: Int, key: String) in LogEntry(timestamp: self.date(iso), tokens: tokens, key: key) }
        let blocks = LocalUsageEstimator.blocks(from: [
            e("2026-10-17T10:20:00Z", 100, "a"), e("2026-10-17T10:20:00Z", 100, "a"),   // duplicate
            e("2026-10-17T12:00:00Z", 50, "b"),
            e("2026-10-17T15:30:00Z", 70, "c"),                                          // after 10:00 + 5h
        ])
        #expect(blocks.count == 2)
        #expect(blocks[0].tokens == 150)
        #expect(blocks[0].start == date("2026-10-17T10:00:00Z") && blocks[0].end == date("2026-10-17T15:00:00Z"))
        #expect(blocks[1].start == date("2026-10-17T15:00:00Z") && blocks[1].tokens == 70)
    }

    @Test func estimateUsesHistoryThenCalibrationThenManual() {
        let blocks = [
            UsageBlock(start: date("2026-10-16T10:00:00Z"), end: date("2026-10-16T15:00:00Z"), tokens: 1000, lastActivity: date("2026-10-16T14:00:00Z")),
            UsageBlock(start: date("2026-10-17T10:00:00Z"), end: date("2026-10-17T15:00:00Z"), tokens: 250, lastActivity: date("2026-10-17T11:00:00Z")),
        ]
        let now = date("2026-10-17T12:00:00Z")
        let history = LocalUsageEstimator.estimate(blocks: blocks, now: now)
        #expect(history.limitSource == .history && history.fraction == 0.25 && history.sessionResetsAt == date("2026-10-17T15:00:00Z"))
        let calibrated = LocalUsageEstimator.estimate(blocks: blocks, now: now, calibratedLimit: 500)
        #expect(calibrated.limitSource == .calibrated && calibrated.fraction == 0.5)
        let manual = LocalUsageEstimator.estimate(blocks: blocks, now: now, manualLimit: 2000, calibratedLimit: 500)
        #expect(manual.limitSource == .manual && manual.fraction == 0.125)
    }

    @Test func noActiveBlockMeansZeroAndNoLimitMeansUnknown() {
        let old = [UsageBlock(start: date("2026-10-10T10:00:00Z"), end: date("2026-10-10T15:00:00Z"), tokens: 800, lastActivity: date("2026-10-10T11:00:00Z"))]
        let idle = LocalUsageEstimator.estimate(blocks: old, now: date("2026-10-17T12:00:00Z"))
        #expect(idle.sessionTokens == 0 && idle.fraction == 0 && idle.sessionResetsAt == nil)
        let none = LocalUsageEstimator.estimate(blocks: [], now: Date())
        #expect(none.fraction == nil && none.limitSource == .unknown)
    }

    @Test func calibration() {
        #expect(LocalUsageEstimator.calibratedLimit(realPercent: 50, localTokens: 1000) == 2000)
        #expect(LocalUsageEstimator.calibratedLimit(realPercent: 1, localTokens: 1000) == nil)
        #expect(LocalUsageEstimator.calibratedLimit(realPercent: 50, localTokens: 0) == nil)
    }
}
