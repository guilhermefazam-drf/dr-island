import SwiftUI

/// ‹ or › next to the sprint's name.
struct SprintStepButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 9, weight: .bold))
                .frame(width: 16, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .accessibilityLabel(label)
    }
}
