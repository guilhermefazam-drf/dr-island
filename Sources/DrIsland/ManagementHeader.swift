import SwiftUI

/// The strip on top of the «Gestão» page: streams, sprint and unit.
struct ManagementHeader: View {
    let store: ManagementStore

    var body: some View {
        HStack(spacing: 8) {
            StreamChips(store: store)
            SprintStepper(store: store)
            UnitToggle(store: store)
        }
        .frame(height: IslandLayout.managementHeader)
    }
}
