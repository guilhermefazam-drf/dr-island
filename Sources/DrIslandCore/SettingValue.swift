import Foundation

/// One preference as it is backed up: the four UserDefaults types the app's settings use, tagged so a number keeps
/// its kind (`{"bool": true}`, `{"int": 3}`, `{"double": 0.5}`, `{"string": "grafite"}`).
public enum SettingValue: Equatable, Sendable, Codable {
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)

    private enum CodingKeys: String, CodingKey { case bool, int, double, string }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let v = try c.decodeIfPresent(Bool.self, forKey: .bool) { self = .bool(v) }
        else if let v = try c.decodeIfPresent(Int.self, forKey: .int) { self = .int(v) }
        else if let v = try c.decodeIfPresent(Double.self, forKey: .double) { self = .double(v) }
        else if let v = try c.decodeIfPresent(String.self, forKey: .string) { self = .string(v) }
        else { throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown setting value")) }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .bool(let v): try c.encode(v, forKey: .bool)
        case .int(let v): try c.encode(v, forKey: .int)
        case .double(let v): try c.encode(v, forKey: .double)
        case .string(let v): try c.encode(v, forKey: .string)
        }
    }

    /// The same kind of value (a remote value only replaces a local one of its kind).
    public func isSameKind(as other: SettingValue) -> Bool {
        switch (self, other) {
        case (.bool, .bool), (.int, .int), (.double, .double), (.string, .string): true
        default: false
        }
    }
}
