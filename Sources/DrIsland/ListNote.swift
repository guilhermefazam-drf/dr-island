import SwiftUI

/// A row that only says something: "A carregar…", "Sem PRs abertos", "+3 não listados".
struct ListNote: View {
    let text: String
    var small = false

    var body: some View {
        Text(text).font(small ? .caption2 : .caption).foregroundStyle(.secondary)
            .frame(height: IslandLayout.prRowHeight, alignment: .leading)
    }
}
