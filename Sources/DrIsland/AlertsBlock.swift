import AppKit
import SwiftUI
import DrIslandCore

struct AlertsBlock: View {
    let entries: [AlertEntry]
    let openAll: () -> Void

    static let maxRows = 4

    static func contentHeight(rows: Int) -> CGFloat {
        IslandLayout.alertsHeader + 6 + CGFloat(rows) * IslandLayout.alertsRow
    }

    var body: some View {
        let shown = Array(entries.prefix(Self.maxRows))
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Avisos recentes", systemImage: "bell").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                Spacer()
                Button(action: openAll) {
                    Text("ver tudo").font(.caption2).foregroundStyle(Color(red: 0.45, green: 0.68, blue: 1.0))
                }
                .buttonStyle(.plain).pointingHandCursor()
            }
            .frame(height: IslandLayout.alertsHeader)
            TimelineView(.periodic(from: .now, by: 60)) { context in
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(shown) { entry in row(entry, now: context.date) }
                }
            }
        }
        .frame(height: Self.contentHeight(rows: shown.count), alignment: .top)
        .blockCard()
    }

    private func row(_ entry: AlertEntry, now: Date) -> some View {
        let content = HStack(spacing: 8) {
            Circle().fill(entry.tone.color).frame(width: 7, height: 7)
            Text(entry.displayMessage).font(.caption).foregroundStyle(.white.opacity(0.9)).lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 4)
            Text(Self.relative(entry.date, now: now)).font(.caption2).foregroundStyle(.secondary).monospacedDigit()
        }
        .frame(height: IslandLayout.alertsRow)
        .contentShape(Rectangle())
        return Group {
            if let url = entry.destination {
                Button { NSWorkspace.shared.open(url) } label: { content }.buttonStyle(.plain).pointingHandCursor()
                    .islandTip("Abrir")
            } else {
                content
            }
        }
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
