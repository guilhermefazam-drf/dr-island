import ServiceManagement
import SwiftUI
import DrIslandCore

/// A "Testar" button with its progress and result; a result starting with "OK" is shown as a success.
struct TestRow: View {
    let title: String
    let running: Bool
    let result: String?
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(title, action: action).disabled(running)
            if running { ProgressView().controlSize(.small) }
            if let result {
                Label(result, systemImage: result.hasPrefix("OK") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
                    .foregroundStyle(result.hasPrefix("OK") ? Color.green : Color.orange)
                    .lineLimit(3)
            }
            Spacer(minLength: 0)
        }
    }
}
