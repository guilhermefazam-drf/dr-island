import SwiftUI

/// ‹ name › to move through the board's sprints (the list is newest first, so ‹ goes to the older one).
struct SprintStepper: View {
    let store: ManagementStore

    var body: some View {
        let sprints = store.sprints
        let index = sprints.firstIndex { $0.id == store.selectedSprint }
        HStack(spacing: 0) {
            SprintStepButton(systemImage: "chevron.left", label: "Sprint anterior") { step(to: index.map { $0 + 1 }) }
                .disabled(index.map { $0 + 1 >= sprints.count } ?? true)
            Text(index.map { sprints[$0].name } ?? "—")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1).truncationMode(.tail)
                .frame(maxWidth: 110)
            SprintStepButton(systemImage: "chevron.right", label: "Sprint seguinte") { step(to: index.map { $0 - 1 }) }
                .disabled(index.map { $0 <= 0 } ?? true)
        }
    }

    private func step(to index: Int?) {
        guard let index, store.sprints.indices.contains(index) else { return }
        store.select(sprint: store.sprints[index].id)
    }
}
