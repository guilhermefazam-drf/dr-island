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

    nonisolated static let maxRows = 5
    nonisolated static let summaryHeight: CGFloat = 16

    nonisolated static func contentHeight(rows: Int) -> CGFloat {
        IslandLayout.alertsHeader + 6 + summaryHeight + 4 + CGFloat(max(rows, 1)) * IslandLayout.alertsRow
    }

    var body: some View {
        let shown = Array(entries.prefix(Self.maxRows))
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(DayBriefing.sinceLabel(since, now: Date()), systemImage: "sunrise").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                Spacer()
                Button(action: dismiss) { Text("ok").font(.caption2.weight(.semibold)).foregroundStyle(linkBlue) }
                    .buttonStyle(.plain).pointingHandCursor()
                    .islandTip("Marcar como visto")
            }
            .frame(height: IslandLayout.alertsHeader)
            Text(entries.isEmpty ? "Sem novidades" : DayBriefing.summary(entries) + (entries.count > Self.maxRows ? " · \(entries.count - Self.maxRows) mais" : ""))
                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                .frame(height: Self.summaryHeight, alignment: .leading)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(shown) { EntryRow(entry: $0, caption: clock($0.date)) }
            }
        }
        .frame(height: Self.contentHeight(rows: shown.count), alignment: .top)
        .blockCard()
    }
}
