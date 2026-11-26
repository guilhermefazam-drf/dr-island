import AppKit
import SwiftUI
import DrIslandCore

/// Bento's strip of recent events under the lists: the latest alerts side by side, each with where it came from and
/// when. At Compacto it is one line: how many, and the latest.
struct BentoEventStrip: View {
    let entries: [AlertEntry]
    /// How many events fit side by side.
    let slots: Int
    let openAll: () -> Void
    @Environment(\.islandPalette) private var palette
    @Environment(\.islandMetrics) private var metrics

    nonisolated private static let chipHeight: CGFloat = 40

    nonisolated static func contentHeight(_ m: IslandMetrics) -> CGFloat {
        m.rowHasMeta ? CGFloat(m.cardHeader) + 4 + chipHeight : CGFloat(m.rowHeight)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            Group {
                if metrics.rowHasMeta { regular(now: context.date) } else { compact(now: context.date) }
            }
        }
        .frame(height: Self.contentHeight(metrics), alignment: .top)
        .blockCard()
    }

    private func regular(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            CardHeader(title: "Avisos", icon: "bell", source: .alerts) {
                Button(action: openAll) { Text("ver tudo").foregroundStyle(Color(palette.info)) }
                    .buttonStyle(.plain).pointingHandCursor()
            }
            HStack(spacing: 8) {
                ForEach(entries.prefix(slots)) { chip($0, now: now) }
                // Keep the chips one width whatever the count.
                ForEach(0..<max(slots - entries.count, 0), id: \.self) { _ in Color.clear.frame(maxWidth: .infinity) }
            }
            .frame(height: Self.chipHeight)
        }
    }

    private func chip(_ entry: AlertEntry, now: Date) -> some View {
        let content = VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(entry.source.title.uppercased())
                    .foregroundStyle(entry.tone.color(in: palette))
                Spacer(minLength: 4)
                Text(AlertsBlock.relative(entry.date, now: now)).foregroundStyle(Color(palette.textTertiary)).monospacedDigit()
            }
            .font(.system(size: CGFloat(metrics.metaSize) - 1, weight: .bold))
            Text(entry.displayMessage)
                .font(.system(size: CGFloat(metrics.metaSize)))
                .foregroundStyle(Color(palette.text))
                .lineLimit(1).truncationMode(.tail)
        }
        .padding(.horizontal, 9)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(palette.surfaceRaised)))
        .contentShape(Rectangle())
        .islandTip(entry.displayMessage)
        return Group {
            if let url = entry.destination {
                Button { NSWorkspace.shared.open(url) } label: { content }.buttonStyle(.plain).pointingHandCursor()
            } else {
                content
            }
        }
    }

    private func compact(now: Date) -> some View {
        HStack(spacing: 8) {
            SourceTile(icon: "bell", source: .alerts)
            if let latest = entries.first {
                (Text("Último aviso").fontWeight(.semibold).foregroundColor(Color(palette.text))
                 + Text(" · \(latest.displayMessage) · \(AlertsBlock.relative(latest.date, now: now))"))
                    .font(.system(size: CGFloat(metrics.bodySize)))
                    .foregroundStyle(Color(palette.textSecondary))
                    .lineLimit(1).truncationMode(.tail)
            }
            Spacer(minLength: 4)
            Button(action: openAll) { Text("ver tudo").foregroundStyle(Color(palette.info)) }
                .buttonStyle(.plain).pointingHandCursor()
                .font(.system(size: CGFloat(metrics.metaSize)))
        }
        .frame(height: CGFloat(metrics.rowHeight))
    }
}
