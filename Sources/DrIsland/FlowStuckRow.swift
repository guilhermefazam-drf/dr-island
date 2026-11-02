import SwiftUI
import DrIslandCore

/// A task that is flagged or has sat in one status for a while.
struct FlowStuckRow: View {
    let task: FlowStuckTask

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: task.isFlagged ? "flag.fill" : "clock").font(.caption2)
                .foregroundStyle(task.isFlagged ? Brand.red : Brand.amber).frame(width: 12)
            Text(task.key).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            Text(task.statusName).font(.caption2).foregroundStyle(.white.opacity(0.85)).lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 4)
            Text("\(Int(task.days.rounded())) d").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
        }
        .frame(height: IslandLayout.managementFlowRow)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(task.key), \(task.statusName), há \(Int(task.days.rounded())) dias\(task.isFlagged ? ", bloqueada" : "")")
    }
}
