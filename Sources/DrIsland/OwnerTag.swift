import SwiftUI
import DrIslandCore

/// The owner's initials on other people's PRs and tasks; nothing on the user's own.
struct OwnerTag: View {
    let name: String?
    let isMine: Bool
    @AppStorage(SettingsKey.showOwner) private var showOwner = true

    var body: some View {
        if showOwner, let label = Owner.label(name: name, isMine: isMine) {
            Text(label)
                .font(.system(size: 9, weight: .bold)).foregroundStyle(.white.opacity(isMine ? 0.95 : 0.7))
                .frame(minWidth: 16)
                .padding(.horizontal, 3).padding(.vertical, 1)
                .background(Capsule().fill(isMine ? Brand.blue.opacity(0.75) : Color.white.opacity(0.14)))
                .islandTip(isMine ? "Teu" : (name ?? ""))
        }
    }
}
