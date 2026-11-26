import SwiftUI

/// The strip on top of the «Gestão» page: streams on the left, the sprint and the unit on the right.
struct ManagementHeader: View {
    let store: ManagementStore

    var body: some View {
        HStack(spacing: 10) {
            StreamChips(store: store)
            Spacer(minLength: 0)
            SprintStepper(store: store)
            UnitToggle(store: store)
        }
        .frame(height: IslandLayout.managementHeader)
    }
}
