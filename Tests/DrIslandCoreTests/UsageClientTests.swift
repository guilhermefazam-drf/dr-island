import Testing
import Foundation
@testable import DrIslandCore

/// Answers every request with a fixed status and body, so the client is exercised without touching the real API.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var status = 200
    nonisolated(unsafe) static var headers: [String: String] = [:]
    nonisolated(unsafe) static var body = Data()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: nil, headerFields: Self.headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@Suite(.serialized) struct UsageClientTests {
    private func client() -> UsageClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return UsageClient(tokenProvider: { "fake-token" }, session: URLSession(configuration: config))
    }

    @Test func fixedSuccessResponse() async throws {
        StubURLProtocol.status = 200
        StubURLProtocol.body = Data(#"{"five_hour":{"utilization":46.0,"resets_at":"2026-10-17T14:50:00+00:00"},"seven_day":{"utilization":57.0,"resets_at":null}}"#.utf8)
        let usage = try await client().fetch()
        #expect(usage.session?.utilization == 46.0)
        #expect(usage.weekly?.utilization == 57.0)
    }

    @Test func fixedRateLimit() async {
        StubURLProtocol.status = 429
        StubURLProtocol.headers = ["Retry-After": "30"]
        StubURLProtocol.body = Data()
        await #expect(throws: UsageError.rateLimited(retryAfter: 30)) { try await client().fetch() }
        StubURLProtocol.headers = [:]
    }
}

@Suite struct RetryDelayTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func secondsHeader() {
        #expect(UsageClient.retryDelay(from: ["retry-after": "90"], now: now) == 90)
    }
    @Test func zeroMeansUnknown() {
        #expect(UsageClient.retryDelay(from: ["retry-after": "0"], now: now) == nil)
        #expect(UsageClient.retryDelay(from: [:], now: now) == nil)
    }
    @Test func resetHeaderAsEpochAndLongestWins() {
        let headers = ["retry-after": "10", "anthropic-ratelimit-unified-reset": String(Int(now.timeIntervalSince1970) + 600)]
        #expect(UsageClient.retryDelay(from: headers, now: now) == 600)
    }
}
