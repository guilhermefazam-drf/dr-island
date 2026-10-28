import Foundation
import DrIslandCore

/// Tokens and estimated API-equivalent cost from the local Claude Code transcripts, refreshed every few minutes.
/// The scanner caches parsed files, so a refresh normally only re-reads the active session's transcript.
@MainActor
final class CostStore: ObservableObject {
    struct Snapshot: Equatable {
        var today = CostSummary.empty
        var week = CostSummary.empty
        var fortnight = CostSummary.empty
    }

    @Published private(set) var snapshot = Snapshot()
    private var loop: Task<Void, Never>?

    func start() {
        loop?.cancel()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(300))
            }
        }
    }

    /// Also called when the settings are opened or the prices change.
    func refresh() async {
        // Off means no scanning of the transcripts at all, not just a hidden number.
        guard Settings.costEnabled else {
            if snapshot != Snapshot() { snapshot = Snapshot() }
            return
        }
        let now = Date()
        let entries = await LocalUsageScanner.entries(now: now)
        let prices = Settings.priceTable
        let startOfDay = Calendar.current.startOfDay(for: now)
        let result = Snapshot(
            today: UsageCost.summarize(entries: entries, since: startOfDay, prices: prices),
            week: UsageCost.summarize(entries: entries, since: now.addingTimeInterval(-7 * 86_400), prices: prices),
            fortnight: UsageCost.summarize(entries: entries, since: now.addingTimeInterval(-14 * 86_400), prices: prices))
        if result != snapshot { snapshot = result }
    }
}
