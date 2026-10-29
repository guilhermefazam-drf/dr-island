import AppKit
import SwiftUI
import DrIslandCore

/// One entry of the alert history as a row: tone dot, message, and a caption on the right. Opens its PR or task when it has one.
struct EntryRow: View {
    let entry: AlertEntry
    let caption: String

    var body: some View {
        let content = HStack(spacing: 8) {
            Circle().fill(entry.tone.color).frame(width: 7, height: 7)
            Text(entry.displayMessage).font(.caption).foregroundStyle(.white.opacity(0.9)).lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 4)
            Text(caption).font(.caption2).foregroundStyle(.secondary).monospacedDigit()
        }
        .frame(height: IslandLayout.alertsRow)
        .contentShape(Rectangle())
        if let url = entry.destination {
            Button { NSWorkspace.shared.open(url) } label: { content }.buttonStyle(.plain).pointingHandCursor().islandTip("Abrir")
        } else {
            content
        }
    }
}
