import SwiftUI

/// A small coloured capsule at the end of a row ("CI falhou", "draft", a task's status…).
struct RowTag: View {
    let text: String
    let color: Color

    init(_ text: String, _ color: Color) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text).font(.system(size: 9, weight: .semibold)).foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 5).padding(.vertical, 1).background(Capsule().fill(color.opacity(0.4)))
    }
}
