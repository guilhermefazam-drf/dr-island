import Foundation

/// Reads the OAuth access token that Claude Code stores in the login keychain.
/// Goes through `/usr/bin/security` so the "Always Allow" keychain approval survives rebuilds
/// of this (ad-hoc signed) app. The token is never logged or persisted by us.
public enum ClaudeCredentials {
    public static let keychainService = "Claude Code-credentials"

    public static func loadAccessToken() async throws -> String {
        let data = try await Task.detached { try readKeychainItem() }.value
        return try parseAccessToken(from: data)
    }

    static func parseAccessToken(from data: Data) throws -> String {
        var json = data
        // `security -w` prints hex when the secret is not printable text.
        if let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !text.hasPrefix("{"), let decoded = Data(hexString: text) {
            json = decoded
        }
        guard let root = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
              let oauth = root["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String, !token.isEmpty else {
            throw UsageError.noCredentials
        }
        return token
    }

    private static func readKeychainItem() throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", keychainService, "-w"]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { throw UsageError.noCredentials }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0, !data.isEmpty else { throw UsageError.noCredentials }
        return data
    }
}

extension Data {
    init?(hexString: String) {
        guard hexString.count % 2 == 0, !hexString.isEmpty else { return nil }
        var bytes = [UInt8]()
        var index = hexString.startIndex
        while index < hexString.endIndex {
            let next = hexString.index(index, offsetBy: 2)
            guard let byte = UInt8(hexString[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        self.init(bytes)
    }
}
