import SwiftUI
import DrIslandCore

/// The two dots under the island: which page it is on, and a way to change it without a touchpad.
struct IslandPageDots: View {
    let page: IslandPage
    let select: (IslandPage) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(IslandPage.allCases, id: \.self) { candidate in
                Button { select(candidate) } label: {
                    Circle()
                        .fill(Color.white.opacity(candidate == page ? 0.8 : 0.25))
                        .frame(width: 5, height: 5)
                        .frame(width: 14, height: 14)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Página \(candidate.rawValue + 1) de \(IslandPage.allCases.count): \(candidate.title)")
                .accessibilityAddTraits(candidate == page ? .isSelected : [])
            }
        }
    }
}
