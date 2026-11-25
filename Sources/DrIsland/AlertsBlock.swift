import AppKit
import SwiftUI
import DrIslandCore

struct AlertsBlock: View {
    @Environment(\.islandPalette) private var palette
    let entries: [AlertEntry]
    let openAll: () -> Void
    @Environment(\.islandMetrics) private var metrics

    static let maxRows = 4

    static func contentHeight(rows: Int, metrics m: IslandMetrics) -> CGFloat {
        CGFloat(m.cardHeader) + 4 + CGFloat(rows) * EntryRow.height(m)
    }

    var body: some View {
        let shown = Array(entries.prefix(Self.maxRows))
        VStack(alignment: .leading, spacing: 4) {
            CardHeader(title: "Avisos", icon: "bell", source: .alerts, count: entries.count.nonZero) {
                Button(action: openAll) { Text("ver tudo").foregroundStyle(Color(palette.info)) }
                    .buttonStyle(.plain).pointingHandCursor()
            }
            TimelineView(.periodic(from: .now, by: 60)) { context in
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(shown) { EntryRow(entry: $0, caption: Self.relative($0.date, now: context.date)) }
                }
            }
        }
        .frame(height: Self.contentHeight(rows: shown.count, metrics: metrics), alignment: .top)
        .blockCard()
    }

    /// "agora", "5 min", "2 h", "ontem".
    static func relative(_ date: Date, now: Date) -> String {
        let seconds = Int(now.timeIntervalSince(date))
        switch seconds {
        case ..<60: return "agora"
        case ..<3600: return "\(seconds / 60) min"
        case ..<86_400: return "\(seconds / 3600) h"
        default:
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
            return Calendar.current.isDate(date, inSameDayAs: yesterday) ? "ontem" : "\(seconds / 86_400) d"
        }
    }
}
