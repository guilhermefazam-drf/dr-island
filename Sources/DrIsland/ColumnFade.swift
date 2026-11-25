import SwiftUI

/// Fades the bottom of a scrolling column that has more below, instead of cutting it off.
struct ColumnFade: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        content.mask {
            VStack(spacing: 0) {
                Rectangle()
                LinearGradient(colors: [.black, .black.opacity(active ? 0 : 1)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 42)
            }
        }
    }
}

extension View {
    func columnFade(active: Bool) -> some View { modifier(ColumnFade(active: active)) }
}
