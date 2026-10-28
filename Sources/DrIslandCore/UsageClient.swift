import Foundation

public enum UsageError: Error, Equatable {
    case noCredentials
    case unauthorized
    case rateLimited(retryAfter: TimeInterval?)
    case http(Int)
    case network
    case invalidResponse
}

public struct UsageClient: Sendable {
    public typealias TokenProvider = @Sendable () async throws -> String

    public static let defaultEndpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    private let tokenProvider: TokenProvider
    private let session: URLSession
    private let endpoint: URL

    public init(
        tokenProvider: @escaping TokenProvider = { try await ClaudeCredentials.loadAccessToken() },
        session: URLSession = .shared,
        endpoint: URL = UsageClient.defaultEndpoint
    ) {
        self.tokenProvider = tokenProvider
        self.session = session
        self.endpoint = endpoint
    }

    public func fetch() async throws -> Usage {
        let token = try await tokenProvider()
        var request = URLRequest(url: endpoint, timeoutInterval: 15)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("dr-island/0.1", forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request) } catch { throw UsageError.network }
        guard let http = response as? HTTPURLResponse else { throw UsageError.invalidResponse }

        switch http.statusCode {
        case 200..<300:
            do { return try UsageParser.parse(data) } catch { throw UsageError.invalidResponse }
        case 401, 403:
            throw UsageError.unauthorized
        case 429:
            throw UsageError.rateLimited(retryAfter: Self.retryDelay(from: http.allHeaderFields.reduce(into: [String: String]()) { if let k = $1.key as? String, let v = $1.value as? String { $0[k.lowercased()] = v } }))
        default:
            throw UsageError.http(http.statusCode)
        }
    }

    /// How long the server says to wait, from `Retry-After` (seconds or an HTTP date) or the rate-limit reset headers
    /// (epoch seconds or ISO 8601). `nil` when none gives a positive wait. Header names are lowercased.
    static func retryDelay(from headers: [String: String], now: Date = Date()) -> TimeInterval? {
        var candidates: [TimeInterval] = []
        if let value = headers["retry-after"] {
            if let seconds = TimeInterval(value) { candidates.append(seconds) }
            else if let date = Self.httpDate.date(from: value) { candidates.append(date.timeIntervalSince(now)) }
        }
        for (name, value) in headers where name.hasPrefix("anthropic-ratelimit") && name.hasSuffix("reset") {
            if let epoch = TimeInterval(value) { candidates.append((epoch > 1e12 ? epoch / 1000 : epoch) - now.timeIntervalSince1970) }
            else if let date = UsageParser.parseDate(value) { candidates.append(date.timeIntervalSince(now)) }
        }
        return candidates.filter { $0 > 0 && $0 < 24 * 3600 }.max()
    }

    private static let httpDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "GMT")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return f
    }()
}
