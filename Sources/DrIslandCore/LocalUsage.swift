import Foundation

/// One assistant response found in a Claude Code transcript (`~/.claude/projects/**/*.jsonl`).
public struct LogEntry: Equatable, Sendable {
    public let timestamp: Date
    public let tokens: Int
    /// `message.id` + `requestId`: the same response is logged once per content block, so this dedupes them.
    public let key: String
    /// The parts of `tokens` plus cache reads, and the model, for cost estimates.
    public let input: Int, output: Int, cacheWrite: Int, cacheRead: Int
    public let model: String

    public init(timestamp: Date, tokens: Int, key: String, input: Int = 0, output: Int = 0, cacheWrite: Int = 0, cacheRead: Int = 0, model: String = "") {
        self.timestamp = timestamp; self.tokens = tokens; self.key = key
        self.input = input; self.output = output; self.cacheWrite = cacheWrite; self.cacheRead = cacheRead; self.model = model
    }
}

public enum LogLineParser {
    private static let usageMarker = Data(#""usage":{"#.utf8)

    /// Cheap pre-filter + targeted extraction: transcripts are huge, so full-line JSON parsing is avoided.
    /// Counts input + output + cache-creation tokens (cache reads are far cheaper against the limit).
    public static func parse(line: Data) -> LogEntry? {
        guard let usageRange = line.range(of: usageMarker),
              let usageObject = balancedObject(in: line, from: usageRange.upperBound - 1),
              let usage = (try? JSONSerialization.jsonObject(with: usageObject)) as? [String: Any],
              let text = String(data: line, encoding: .utf8),
              let stamp = string(after: #""timestamp":""#, in: text),
              let timestamp = parseTimestamp(stamp) else { return nil }
        func number(_ key: String) -> Int { (usage[key] as? NSNumber)?.intValue ?? 0 }
        let tokens = number("input_tokens") + number("output_tokens") + number("cache_creation_input_tokens")
        guard tokens > 0 else { return nil }
        let messageID = string(after: #""id":"msg_"#, in: text).map { "msg_" + $0 } ?? ""
        let requestID = string(after: #""requestId":""#, in: text) ?? ""
        let key = messageID.isEmpty && requestID.isEmpty ? "\(timestamp.timeIntervalSince1970)-\(tokens)" : messageID + "|" + requestID
        return LogEntry(timestamp: timestamp, tokens: tokens, key: key,
                        input: number("input_tokens"), output: number("output_tokens"),
                        cacheWrite: number("cache_creation_input_tokens"), cacheRead: number("cache_read_input_tokens"),
                        model: string(after: #""model":""#, in: text) ?? "")
    }

    public static func parse(file data: Data, since cutoff: Date) -> [LogEntry] {
        var entries: [LogEntry] = []
        for line in data.split(separator: 0x0A, omittingEmptySubsequences: true) {
            if let entry = parse(line: Data(line)), entry.timestamp >= cutoff { entries.append(entry) }
        }
        return entries
    }

    private static func string(after marker: String, in text: String) -> String? {
        guard let start = text.range(of: marker)?.upperBound,
              let end = text[start...].firstIndex(of: "\"") else { return nil }
        return String(text[start..<end])
    }

    /// Returns the `{…}` object starting at `from` (index of the opening brace), honouring nesting and strings.
    private static func balancedObject(in data: Data, from start: Data.Index) -> Data? {
        var depth = 0, inString = false, escaped = false
        var index = start
        while index < data.endIndex {
            let byte = data[index]
            if inString {
                if escaped { escaped = false } else if byte == 0x5C { escaped = true } else if byte == 0x22 { inString = false }
            } else if byte == 0x22 {
                inString = true
            } else if byte == 0x7B {
                depth += 1
            } else if byte == 0x7D {
                depth -= 1
                if depth == 0 { return data[start...index] }
            }
            index += 1
        }
        return nil
    }

    /// Parses `2026-10-17T10:37:59.007Z` without `ISO8601DateFormatter` (much faster over large logs).
    static func parseTimestamp(_ text: String) -> Date? {
        let u = Array(text.utf8)
        guard u.count >= 20, u[4] == 0x2D, u[7] == 0x2D, u[10] == 0x54, u[13] == 0x3A, u[16] == 0x3A else { return nil }
        func int(_ range: Range<Int>) -> Int? { Int(String(decoding: u[range], as: UTF8.self)) }
        guard let y = int(0..<4), let mo = int(5..<7), let d = int(8..<10),
              let h = int(11..<13), let mi = int(14..<16), let s = int(17..<19) else { return nil }
        var fraction = 0.0
        var cursor = 19
        if cursor < u.count, u[cursor] == 0x2E {
            var digits = ""
            cursor += 1
            while cursor < u.count, u[cursor] >= 0x30, u[cursor] <= 0x39 { digits.append(Character(UnicodeScalar(u[cursor]))); cursor += 1 }
            fraction = Double("0." + digits) ?? 0
        }
        // Only UTC ("Z") timestamps are produced by Claude Code; anything else is ignored.
        guard cursor < u.count, u[cursor] == 0x5A else { return nil }
        // Days since 1970-01-01 (Howard Hinnant's civil-from-days algorithm, inverted).
        let yy = mo <= 2 ? y - 1 : y
        let era = (yy >= 0 ? yy : yy - 399) / 400
        let yoe = yy - era * 400
        let doy = (153 * (mo + (mo > 2 ? -3 : 9)) + 2) / 5 + d - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        let days = era * 146_097 + doe - 719_468
        return Date(timeIntervalSince1970: Double(days * 86_400 + h * 3600 + mi * 60 + s) + fraction)
    }
}

public struct UsageBlock: Equatable, Sendable {
    public let start: Date
    public let end: Date
    public var tokens: Int
    public var lastActivity: Date
}

public struct LocalEstimate: Equatable, Sendable {
    public enum LimitSource: Equatable, Sendable { case manual, calibrated, history, unknown }

    public let sessionTokens: Int
    public let sessionResetsAt: Date?
    /// nil when no limit can be inferred yet.
    public let fraction: Double?
    public let limitTokens: Double?
    public let limitSource: LimitSource
}

public enum LocalUsageEstimator {
    public static let window: TimeInterval = 5 * 3600

    /// Groups entries into 5-hour session blocks (a block starts at the top of the hour of its first message).
    public static func blocks(from entries: [LogEntry]) -> [UsageBlock] {
        var seen = Set<String>()
        let unique = entries.filter { seen.insert($0.key).inserted }.sorted { $0.timestamp < $1.timestamp }
        var blocks: [UsageBlock] = []
        for entry in unique {
            if var current = blocks.last,
               entry.timestamp < current.end, entry.timestamp.timeIntervalSince(current.lastActivity) < window {
                current.tokens += entry.tokens
                current.lastActivity = entry.timestamp
                blocks[blocks.count - 1] = current
            } else {
                let hour = floor(entry.timestamp.timeIntervalSince1970 / 3600) * 3600
                let start = Date(timeIntervalSince1970: hour)
                blocks.append(UsageBlock(start: start, end: start.addingTimeInterval(window), tokens: entry.tokens, lastActivity: entry.timestamp))
            }
        }
        return blocks
    }

    /// Limit priority: manual setting, then a calibration against a real API reading, then the biggest past block.
    public static func estimate(blocks: [UsageBlock], now: Date, manualLimit: Double? = nil, calibratedLimit: Double? = nil) -> LocalEstimate {
        let active = blocks.last { $0.start <= now && now < $0.end }
        let tokens = active?.tokens ?? 0
        let historyLimit = blocks.filter { $0 != active }.map(\.tokens).max().map(Double.init)

        let limit: Double?
        let source: LocalEstimate.LimitSource
        if let manualLimit, manualLimit > 0 { limit = manualLimit; source = .manual }
        else if let calibratedLimit, calibratedLimit > 0 { limit = calibratedLimit; source = .calibrated }
        else if let historyLimit, historyLimit > 0 { limit = historyLimit; source = .history }
        else { limit = nil; source = .unknown }

        return LocalEstimate(
            sessionTokens: tokens,
            sessionResetsAt: active?.end,
            fraction: limit.map { min(Double(tokens) / $0, 1) },
            limitTokens: limit,
            limitSource: source
        )
    }

    /// Tokens that correspond to 100% of the session, from a real API percentage and the local token count.
    /// Ignores very low readings, where rounding makes the ratio meaningless.
    public static func calibratedLimit(realPercent: Double, localTokens: Int) -> Double? {
        guard realPercent >= 3, localTokens > 0 else { return nil }
        return Double(localTokens) / (realPercent / 100)
    }
}
