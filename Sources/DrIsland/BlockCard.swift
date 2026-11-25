import SwiftUI
import DrIslandCore

/// The panel every island block sits on (see `BlockCardStyle`). `active` tints it with the accent (the running sprint).
struct BlockCard<Content: View>: View {
    var active = false
    @ViewBuilder var content: Content

    var body: some View {
        content.modifier(BlockCardStyle(active: active))
    }
}
