import SwiftUI
import DrIslandCore

/// The owner's initials on other people's PRs and tasks; nothing on the user's own.
struct OwnerTag: View {
    let name: String?
    let isMine: Bool
    @AppStorage(SettingsKey.showOwner) private var showOwner = true
    @Environment(\.islandPalette) private var palette

    var body: some View {
        if showOwner, let label = Owner.label(name: name, isMine: isMine) {
            Text(label)
                .font(.system(size: 9, weight: .bold)).foregroundStyle(isMine ? Color.white.opacity(0.95) : Color(palette.text).opacity(0.7))
                .frame(minWidth: 16)
                .padding(.horizontal, 3).padding(.vertical, 1)
                .background(Capsule().fill(isMine ? Color(palette.accent).opacity(0.75) : Color(palette.text).opacity(0.14)))
                .islandTip(isMine ? "Teu" : (name ?? ""))
        }
    }
}
