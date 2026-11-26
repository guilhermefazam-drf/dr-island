import SwiftUI
import DrIslandCore

/// A task that is flagged or has sat in one status for a while, as a row of the island's lists: the icon, the key,
/// the status and a pill with the days.
struct FlowStuckRow: View {
    @Environment(\.islandPalette) private var palette
    @Environment(\.islandMetrics) private var metrics
    let task: FlowStuckTask

    /// One line, so shorter than a list row with its meta line.
    static func height(_ m: IslandMetrics) -> CGFloat { m.rowHasMeta ? 26 : CGFloat(m.rowHeight) }

    var body: some View {
        let tone = task.isFlagged ? Color(palette.red) : Color(palette.amber)
        HStack(spacing: 8) {
            Image(systemName: task.isFlagged ? "flag.fill" : "clock").font(.system(size: 11)).foregroundStyle(tone).frame(width: 14)
            Text(task.key).font(.system(size: CGFloat(metrics.metaSize), weight: .medium, design: .monospaced))
                .foregroundStyle(Color(palette.textTertiary))
            Text(task.statusName + (task.isFlagged ? " · bloqueada" : ""))
                .font(.system(size: CGFloat(metrics.bodySize))).foregroundStyle(Color(palette.text))
                .lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 4)
            Pill("\(Int(task.days.rounded())) d", tone)
        }
        .frame(height: Self.height(metrics))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(task.key), \(task.statusName), há \(Int(task.days.rounded())) dias\(task.isFlagged ? ", bloqueada" : "")")
    }
}
