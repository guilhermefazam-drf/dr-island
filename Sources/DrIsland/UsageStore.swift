import Foundation
import DrIslandCore

@MainActor
final class UsageStore: ObservableObject {
    enum Status: Equatable {
        case loading, ok, noCredentials, unauthorized, offline, rateLimited
    }

    @Published private(set) var sessionFraction: Double = 0
    @Published private(set) var sessionResetsAt: Date?
    @Published private(set) var weeklyFraction: Double?
    @Published private(set) var weeklyResetsAt: Date?
    @Published private(set) var status: Status = .loading
    /// True once we have any real reading (fresh or cached), so a failing refresh can keep showing it dimmed.
    @Published private(set) var hasValue = false
    /// True while the numbers come from the local-log estimate instead of the API.
    @Published private(set) var isEstimate = false
    /// True while a request to the usage endpoint is in flight (shown in the island as "A atualizar…").
    @Published private(set) var isRefreshing = false
    /// Bumped on every fresh reading from the API (even an unchanged one), so the island can play its update animation.
    @Published private(set) var updateTick = 0
    /// Bumped when a new session window starts (after a reset, or the first message after an idle spell), so the island can flag it.
    @Published private(set) var newSessionTick = 0
    /// Called after `newSessionTick` is bumped, for the mini island notice.
    var onNewSession: (() -> Void)?

    /// When the session window will hit 100% at the current pace (only if before it resets).
    @Published private(set) var sessionExhaustsAt: Date?

    private var sessionSamples: [UsageSample] = []
    /// Daily peaks for the history chart; only real readings are recorded.
    @Published private(set) var history: [DayUsage] = UsageHistory.decode(UserDefaults.standard.string(forKey: SettingsKey.usageHistory) ?? "[]")

    private struct Cache: Codable {
        var session: Double
        var sessionResetsAt: Date?
        var weekly: Double?
        var weeklyResetsAt: Date?
        var fetchedAt: Date
    }

    private static let cacheKey = "usageCache"
    /// The usage endpoint rate-limits aggressively, so never hit it more often than this (also on "Atualizar agora").
    private static let minimumGap: TimeInterval = 20

    private let client: UsageClient
    private var loop: Task<Void, Never>?
    private var failures = 0
    private var fetchedAt: Date?
    private var lastAttempt: Date?
    /// After a 429, even a manual refresh must wait: the endpoint stays limited for a while.
    private var blockedUntil: Date? { didSet { retryAt = blockedUntil } }
    /// When the API will be asked again after a 429 (nil when not limited).
    @Published private(set) var retryAt: Date?
    /// True when `blockedUntil` came from the server's own wait: not even a manual refresh may cut it short.
    private var blockFromServer = false
    private var lastCalibration: Date?
    /// Set by "Atualizar agora": the next cycle skips the cache, the rate-limit block and the minimum gap.
    private var manualRequest = false
    private static let manualDebounce: TimeInterval = 3

    init(client: UsageClient = UsageClient()) {
        self.client = client
        loadCache()
    }

    /// "até 14:32" while the API is limited and a retry time is known.
    var retryHint: String {
        guard let retryAt, retryAt > Date() else { return "" }
        return " · volta às " + retryAt.formatted(date: .omitted, time: .shortened)
    }

    func start() {
        loop?.cancel()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let delay = await self.refresh()
                try? await Task.sleep(for: .seconds(delay))
            }
        }
    }

    /// A manual refresh is explicit, so it may retry even while blocked after a 429 (a new 429 blocks again).
    /// It never interrupts a request already in flight: cancelling it would only record a bogus network failure.
    func refreshNow() {
        guard !isRefreshing else { return }
        manualRequest = true
        start()
    }

    /// Returns how long to wait before the next refresh.
    private func refresh() async -> TimeInterval {
        if let fake = Self.fakeFraction() {
            show(Usage(session: UsageWindow(utilization: fake * 100, resetsAt: Date().addingTimeInterval(2 * 3600 + 14 * 60)),
                       weekly: UsageWindow(utilization: 57, resetsAt: Date().addingTimeInterval(3 * 86400))))
            status = .ok
            updateTick += 1
            return 5
        }
        let interval = Settings.claudeRefreshSeconds
        let manual = manualRequest
        manualRequest = false
        // Right after a launch, a recent cached reading is enough: don't spend a request on it.
        if !manual, failures == 0, let fetchedAt, hasValue {
            let wait = interval - Date().timeIntervalSince(fetchedAt)
            if wait > 1, lastAttempt == nil { lastAttempt = Date(); return wait }
        }
        if let blockedUntil, blockedUntil > Date(), !manual || blockFromServer {
            await applyEstimate()
            return min(blockedUntil.timeIntervalSinceNow, 60)
        }
        let gap = manual ? Self.manualDebounce : Self.minimumGap
        if let lastAttempt, Date().timeIntervalSince(lastAttempt) < gap {
            return gap - Date().timeIntervalSince(lastAttempt)
        }
        lastAttempt = Date()
        isRefreshing = true
        // The ring's update animation plays once per attempt, whether it succeeded or failed (rate limit, offline…).
        defer { isRefreshing = false; updateTick += 1 }
        do {
            let usage = try await client.fetch()
            show(usage)
            save(usage)
            isEstimate = false
            status = .ok
            calibrateInBackground(with: usage)
            failures = 0
            blockedUntil = nil
            blockFromServer = false
            return interval
        } catch let error as UsageError {
            failures += 1
            if case .rateLimited = error {} else { ErrorLog.record("Claude", error: error) }
            switch error {
            case .noCredentials: status = .noCredentials
            case .unauthorized: status = .unauthorized
            case .rateLimited(let retryAfter):
                status = .rateLimited
                // The server's own wait wins over every refresh interval of ours: asking earlier only gets another 429.
                // Without a usable header (Retry-After is often 0) fall back to 5 minutes, doubling up to 15.
                let serverWait = retryAfter.flatMap { $0 > 0 ? $0 + 2 : nil }
                let wait = serverWait ?? min(300 * pow(2, Double(min(failures - 1, 2))), 900)
                blockedUntil = Date().addingTimeInterval(wait)
                blockFromServer = serverWait != nil
                await applyEstimate()
                return min(wait, 60)   // keeps the estimate fresh; the API itself stays blocked until `blockedUntil`
            default: status = .offline
            }
            await applyEstimate()
            return backoff(base: interval)
        } catch {
            failures += 1
            ErrorLog.record("Claude", error: error)
            status = .offline
            await applyEstimate()
            return backoff(base: interval)
        }
    }

    // MARK: Local-log fallback

    /// Replaces the shown numbers with an estimate from the local transcripts while the API is unavailable.
    private func applyEstimate() async {
        guard Settings.claudeLocalFallback, status == .rateLimited || status == .offline else { return }
        let now = Date()
        let estimate = LocalUsageEstimator.estimate(
            blocks: await LocalUsageScanner.scan(now: now), now: now,
            manualLimit: Settings.claudeManualLimit, calibratedLimit: Settings.usageCalibrationLimit)
        guard let fraction = estimate.fraction else { return }
        // An uncalibrated guess must not replace a recent real reading.
        let realIsRecent = !isEstimate && hasValue && (fetchedAt.map { now.timeIntervalSince($0) < 30 * 60 } ?? false)
        if estimate.limitSource == .history && realIsRecent { return }
        sessionFraction = fraction
        sessionResetsAt = estimate.sessionResetsAt
        hasValue = true
        isEstimate = true
    }

    /// Learns how many local tokens equal 100% from a real reading, so later estimates match the plan's real limit.
    private func calibrateInBackground(with usage: Usage) {
        guard Settings.claudeLocalFallback, let percent = usage.session?.utilization, percent >= 3,
              lastCalibration.map({ Date().timeIntervalSince($0) > 10 * 60 }) ?? true else { return }
        lastCalibration = Date()
        Task {
            let now = Date()
            let blocks = await LocalUsageScanner.scan(now: now)
            let tokens = LocalUsageEstimator.estimate(blocks: blocks, now: now).sessionTokens
            if let limit = LocalUsageEstimator.calibratedLimit(realPercent: percent, localTokens: tokens) {
                Settings.usageCalibrationLimit = limit
            }
        }
    }

    private func backoff(base: TimeInterval) -> TimeInterval {
        min(base * pow(2, Double(min(failures - 1, 4))), 600)
    }

    private func show(_ usage: Usage) {
        detectNewSession(in: usage)
        trackForecast(usage)
        recordHistory(usage)
        // No active session window means nothing has been spent yet.
        sessionFraction = usage.session?.fraction ?? 0
        sessionResetsAt = usage.session?.resetsAt
        weeklyFraction = usage.weekly?.fraction
        weeklyResetsAt = usage.weekly?.resetsAt
        hasValue = true
    }

    /// Plays the new-session animation from the settings window.
    func simulateNewSession() { newSessionTick += 1; onNewSession?() }

    /// A real reading whose session window ends clearly later than the previous one (or that had none) is a new session.
    /// The first reading after launch and estimates from the local logs only seed the comparison.
    private func detectNewSession(in usage: Usage) {
        guard hasValue, !isEstimate, Self.fakeFraction() == nil, let start = usage.session?.resetsAt else { return }
        if let previous = sessionResetsAt, start.timeIntervalSince(previous) <= 10 * 60 { return }
        newSessionTick += 1
        onNewSession?()
    }

    private func recordHistory(_ usage: Usage) {
        guard Self.fakeFraction() == nil else { return }
        history = UsageHistory.recording(session: usage.session?.fraction ?? 0, weekly: usage.weekly?.fraction, into: history)
        UserDefaults.standard.set(UsageHistory.encode(history), forKey: SettingsKey.usageHistory)
    }

    // MARK: Forecast

    private func trackForecast(_ usage: Usage) {
        guard let session = usage.session else { sessionSamples = []; sessionExhaustsAt = nil; return }
        // A lower value or a new reset time means a new window: old samples no longer apply.
        if let last = sessionSamples.last, session.fraction < last.fraction { sessionSamples = [] }
        sessionSamples.append(UsageSample(date: Date(), fraction: session.fraction))
        sessionSamples = Array(sessionSamples.suffix(60))
        sessionExhaustsAt = UsageAlerts.exhaustion(samples: sessionSamples, resetsAt: session.resetsAt)
    }

    // MARK: Cache (non-secret numbers only)

    private func save(_ usage: Usage) {
        let now = Date()
        fetchedAt = now
        let cache = Cache(session: usage.session?.utilization ?? 0, sessionResetsAt: usage.session?.resetsAt,
                          weekly: usage.weekly?.utilization, weeklyResetsAt: usage.weekly?.resetsAt, fetchedAt: now)
        if let data = try? JSONEncoder().encode(cache) { UserDefaults.standard.set(data, forKey: Self.cacheKey) }
    }

    private func loadCache() {
        guard Self.fakeFraction() == nil,
              let data = UserDefaults.standard.data(forKey: Self.cacheKey),
              let cache = try? JSONDecoder().decode(Cache.self, from: data) else { return }
        // A session window that already reset means the cached percentage no longer applies.
        let sessionExpired = cache.sessionResetsAt.map { $0 < Date() } ?? false
        sessionFraction = sessionExpired ? 0 : min(max(cache.session / 100, 0), 1)
        sessionResetsAt = sessionExpired ? nil : cache.sessionResetsAt
        let weeklyExpired = cache.weeklyResetsAt.map { $0 < Date() } ?? false
        weeklyFraction = weeklyExpired ? nil : cache.weekly.map { min(max($0 / 100, 0), 1) }
        weeklyResetsAt = weeklyExpired ? nil : cache.weeklyResetsAt
        fetchedAt = cache.fetchedAt
        hasValue = true
        status = .ok
    }

    /// `DR_ISLAND_FAKE=0.0…1.0` bypasses the network to preview colours and animation.
    private static func fakeFraction() -> Double? {
        ProcessInfo.processInfo.environment["DR_ISLAND_FAKE"].flatMap(Double.init).map { min(max($0, 0), 1) }
    }
}
