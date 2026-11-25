import SwiftUI

/// Fades the bottom of a scrolling column that has more below, instead of cutting it off.
/// The column's content must end with `ColumnFade.height` of padding when active, so it can scroll clear of the fade.
struct ColumnFade: ViewModifier {
    static let height: CGFloat = 42
    let active: Bool

    func body(content: Content) -> some View {
        if active {
            content.mask {
                VStack(spacing: 0) {
                    Rectangle()
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: Self.height)
                }
            }
        } else {
            content
        }
    }
}

extension View {
    func columnFade(active: Bool) -> some View { modifier(ColumnFade(active: active)) }
}
