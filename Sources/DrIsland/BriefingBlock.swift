import AppKit
import SwiftUI
import DrIslandCore

func clock(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    return f.string(from: date)
}

/// «O que mudou desde…»: the entries newer than the last look, with a count per source and a button to dismiss it.
struct BriefingBlock: View {
    let entries: [AlertEntry]
    let since: Date
    let dismiss: () -> Void
    @Environment(\.islandPalette) private var palette
    @Environment(\.islandMetrics) private var metrics

    nonisolated static let maxRows = 5
    nonisolated static let summaryHeight: CGFloat = 16

    nonisolated static func contentHeight(rows: Int, metrics m: IslandMetrics) -> CGFloat {
        CGFloat(m.cardHeader) + 4 + summaryHeight + 4 + CGFloat(max(rows, 1)) * EntryRow.height(m)
    }

    var body: some View {
        let shown = Array(entries.prefix(Self.maxRows))
        VStack(alignment: .leading, spacing: 4) {
            CardHeader(title: DayBriefing.sinceLabel(since, now: Date()), icon: "sunrise", source: .briefing) {
                Button(action: dismiss) { Text("ok").fontWeight(.semibold).foregroundStyle(Color(palette.info)) }
                    .buttonStyle(.plain).pointingHandCursor()
                    .islandTip("Marcar como visto")
            }
            Text(entries.isEmpty ? "Sem novidades" : DayBriefing.summary(entries) + (entries.count > Self.maxRows ? " · \(entries.count - Self.maxRows) mais" : ""))
                .font(.system(size: CGFloat(metrics.metaSize))).foregroundStyle(Color(palette.textSecondary)).lineLimit(1)
                .frame(height: Self.summaryHeight, alignment: .leading)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(shown) { EntryRow(entry: $0, caption: clock($0.date)) }
            }
        }
        .frame(height: Self.contentHeight(rows: shown.count, metrics: metrics), alignment: .top)
        .blockCard()
    }
}
