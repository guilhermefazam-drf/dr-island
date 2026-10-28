import Foundation

public enum ModelFamily: String, CaseIterable, Codable, Sendable {
    case opus, sonnet, haiku, other

    public init(model: String) {
        let name = model.lowercased()
        if name.contains("opus") { self = .opus }
        else if name.contains("sonnet") { self = .sonnet }
        else if name.contains("haiku") { self = .haiku }
        else { self = .other }
    }

    public var title: String {
        switch self {
        case .opus: return "Opus"
        case .sonnet: return "Sonnet"
        case .haiku: return "Haiku"
        case .other: return "Outros"
        }
    }
}

/// US dollars per million tokens. Cache writes cost 1.25× the input price and cache reads 0.1×.
public struct ModelPrice: Codable, Equatable, Sendable {
    public var input: Double
    public var output: Double
    public init(input: Double, output: Double) { self.input = input; self.output = output }
}

public struct PriceTable: Codable, Equatable, Sendable {
    public var prices: [ModelFamily: ModelPrice]

    /// Editable in the settings: Anthropic changes prices and adds models, so these are only starting points.
    public static let standard = PriceTable(prices: [
        .opus: ModelPrice(input: 5, output: 25),
        .sonnet: ModelPrice(input: 3, output: 15),
        .haiku: ModelPrice(input: 1, output: 5),
        .other: ModelPrice(input: 3, output: 15),
    ])

    public init(prices: [ModelFamily: ModelPrice]) { self.prices = prices }

    public func price(for family: ModelFamily) -> ModelPrice { prices[family] ?? Self.standard.prices[family] ?? ModelPrice(input: 3, output: 15) }

    public static func decode(_ json: String?) -> PriceTable {
        json?.data(using: .utf8).flatMap { try? JSONDecoder().decode(PriceTable.self, from: $0) } ?? .standard
    }

    public func encoded() -> String {
        (try? JSONEncoder().encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }
}

public struct CostSummary: Equatable, Sendable {
    public struct Line: Equatable, Sendable {
        public var tokens = 0       // input + output + cache writes (cache reads left out: they are very cheap and huge)
        public var cacheReadTokens = 0
        public var cost = 0.0
    }

    public var total = Line()
    public var byFamily: [ModelFamily: Line] = [:]

    public static let empty = CostSummary()
}

public enum UsageCost {
    /// Cost and tokens of every response since `cutoff`. Responses are deduplicated by their key, as in the session blocks.
    public static func summarize(entries: [LogEntry], since cutoff: Date, prices: PriceTable = .standard) -> CostSummary {
        var seen = Set<String>()
        var summary = CostSummary()
        for entry in entries where entry.timestamp >= cutoff && seen.insert(entry.key).inserted {
            let family = ModelFamily(model: entry.model)
            let price = prices.price(for: family)
            let cost = (Double(entry.input) * price.input + Double(entry.output) * price.output
                        + Double(entry.cacheWrite) * price.input * 1.25 + Double(entry.cacheRead) * price.input * 0.1) / 1_000_000
            summary.total.tokens += entry.tokens
            summary.total.cacheReadTokens += entry.cacheRead
            summary.total.cost += cost
            var line = summary.byFamily[family] ?? CostSummary.Line()
            line.tokens += entry.tokens
            line.cacheReadTokens += entry.cacheRead
            line.cost += cost
            summary.byFamily[family] = line
        }
        return summary
    }

    /// "1,2 M", "340 mil", "850".
    public static func compactTokens(_ tokens: Int) -> String {
        switch tokens {
        case 1_000_000...: return String(format: "%.1f M", Double(tokens) / 1_000_000).replacingOccurrences(of: ".", with: ",")
        case 1_000...: return "\(Int((Double(tokens) / 1000).rounded())) mil"
        default: return "\(tokens)"
        }
    }

    public static func dollars(_ cost: Double) -> String {
        (cost < 10 ? String(format: "$%.2f", cost) : String(format: "$%.0f", cost)).replacingOccurrences(of: ".", with: ",")
    }
}
