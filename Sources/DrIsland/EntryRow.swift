import AppKit
import SwiftUI
import DrIslandCore

/// One entry of the alert history as a row: tone dot, message, and a caption on the right. Opens its PR or task when it has one.
struct EntryRow: View {
    let entry: AlertEntry
    let caption: String
    @Environment(\.islandPalette) private var palette
    @Environment(\.islandMetrics) private var metrics

    /// A history row: a little shorter than a list row, since it is a single line.
    nonisolated static func height(_ m: IslandMetrics) -> CGFloat { m.rowHasMeta ? 26 : 20 }

    var body: some View {
        let content = HStack(spacing: 8) {
            Circle().fill(entry.tone.color(in: palette)).frame(width: 7, height: 7)
            Text(entry.displayMessage).font(.system(size: CGFloat(metrics.bodySize))).foregroundStyle(Color(palette.text)).lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 4)
            Text(caption).font(.system(size: CGFloat(metrics.metaSize))).foregroundStyle(Color(palette.textTertiary)).monospacedDigit()
        }
        .frame(height: Self.height(metrics))
        .contentShape(Rectangle())
        if let url = entry.destination {
            Button { NSWorkspace.shared.open(url) } label: { content }.buttonStyle(.plain).pointingHandCursor().islandTip("Abrir")
        } else {
            content
        }
    }
}
