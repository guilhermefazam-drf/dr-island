import Foundation

/// The app's preferences as they are written to the gist: when they last changed, on which Mac, and the values.
public struct SettingsBackup: Equatable, Sendable {
    public var updatedAt: Date
    public var device: String
    public var values: [String: SettingValue]

    public init(updatedAt: Date, device: String, values: [String: SettingValue]) {
        self.updatedAt = updatedAt; self.device = device; self.values = values
    }

    private struct Wire: Codable {
        var version: Int
        var updatedAt: Date
        var device: String
        var values: [String: Lossy]
    }

    /// A value that no longer decodes is skipped instead of breaking the whole file.
    private struct Lossy: Codable {
        let value: SettingValue?
        init(_ value: SettingValue) { self.value = value }
        init(from decoder: Decoder) throws { value = try? SettingValue(from: decoder) }
        func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
    }

    public func encoded() -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .secondsSince1970   // readable in the gist, and exact
        let wire = Wire(version: 1, updatedAt: updatedAt, device: device, values: values.mapValues(Lossy.init))
        return (try? e.encode(wire)) ?? Data()
    }

    /// `nil` when the data is not a settings backup.
    public static func decode(_ data: Data) -> SettingsBackup? {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        guard let wire = try? d.decode(Wire.self, from: data) else { return nil }
        return SettingsBackup(updatedAt: wire.updatedAt, device: wire.device, values: wire.values.compactMapValues(\.value))
    }
}
