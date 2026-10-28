import Foundation
import Testing
@testable import DrIslandCore

@Suite struct UsageCostTests {
    private let now = Date()
    private func entry(_ key: String, model: String = "claude-sonnet-5-5", input: Int = 0, output: Int = 0,
                       write: Int = 0, read: Int = 0, ago: TimeInterval = 0) -> LogEntry {
        LogEntry(timestamp: now.addingTimeInterval(-ago), tokens: input + output + write, key: key,
                 input: input, output: output, cacheWrite: write, cacheRead: read, model: model)
    }

    @Test func familyFromModelName() {
        #expect(ModelFamily(model: "claude-opus-4-5") == .opus)
        #expect(ModelFamily(model: "claude-sonnet-5-5") == .sonnet)
        #expect(ModelFamily(model: "claude-haiku-5-5") == .haiku)
        #expect(ModelFamily(model: "") == .other)
    }

    @Test func costUsesPricesAndCacheMultipliers() {
        // Sonnet 3/15: 1M input = $3, 1M output = $15, 1M cache write = $3.75, 1M cache read = $0.30.
        let s = UsageCost.summarize(entries: [entry("a", input: 1_000_000, output: 1_000_000, write: 1_000_000, read: 1_000_000)], since: .distantPast)
        #expect(abs(s.total.cost - 22.05) < 0.0001)
        #expect(s.total.tokens == 3_000_000)
        #expect(s.total.cacheReadTokens == 1_000_000)
    }

    @Test func dedupesAndFiltersByDate() {
        let entries = [entry("a", output: 1000), entry("a", output: 1000), entry("old", output: 1000, ago: 10 * 86_400)]
        let s = UsageCost.summarize(entries: entries, since: now.addingTimeInterval(-86_400))
        #expect(s.total.tokens == 1000)
    }

    @Test func splitsByFamily() {
        let s = UsageCost.summarize(entries: [entry("a", model: "claude-opus-4-5", output: 1_000_000), entry("b", output: 1_000_000)], since: .distantPast)
        #expect(abs((s.byFamily[.opus]?.cost ?? 0) - 25) < 0.0001)
        #expect(abs((s.byFamily[.sonnet]?.cost ?? 0) - 15) < 0.0001)
    }

    @Test func customPricesRoundTrip() {
        var table = PriceTable.standard
        table.prices[.opus] = ModelPrice(input: 15, output: 75)
        #expect(PriceTable.decode(table.encoded()) == table)
        #expect(PriceTable.decode("junk") == .standard)
    }

    @Test func formatting() {
        #expect(UsageCost.compactTokens(850) == "850")
        #expect(UsageCost.compactTokens(340_000) == "340 mil")
        #expect(UsageCost.compactTokens(1_300_000) == "1,3 M")
        #expect(UsageCost.dollars(4.1) == "$4,10")
        #expect(UsageCost.dollars(123.4) == "$123")
    }

    @Test func parserFillsBreakdownAndModel() {
        let line = #"{"message":{"model":"claude-opus-4-5","id":"msg_1","usage":{"input_tokens":10,"output_tokens":20,"cache_creation_input_tokens":30,"cache_read_input_tokens":40}},"requestId":"r","timestamp":"2026-10-17T10:37:59.007Z"}"#
        let e = LogLineParser.parse(line: Data(line.utf8))
        #expect(e?.model == "claude-opus-4-5")
        #expect(e?.cacheRead == 40)
        #expect(e?.tokens == 60)
    }
}
