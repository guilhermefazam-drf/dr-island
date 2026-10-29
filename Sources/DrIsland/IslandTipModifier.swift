import AppKit
import SwiftUI
import DrIslandCore

struct IslandTipModifier: ViewModifier {
    /// The view's frame, kept out of SwiftUI state: it changes on every frame while the island animates, and only the
    /// hover reads it, so storing it must not redraw anything.
    private final class Anchor { var frame: CGRect = .zero }

    let text: String
    @Environment(IslandTipCenter.self) private var tips: IslandTipCenter?
    @State private var anchor = Anchor()
    @State private var pending: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(islandRootSpace)) } action: { anchor.frame = $0 }
            .onHover { inside in
                pending?.cancel()
                guard !text.isEmpty else { return }
                guard inside else { tips?.tip = nil; return }
                pending = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(350))
                    guard !Task.isCancelled else { return }
                    tips?.tip = IslandTipData(text: text, anchor: anchor.frame)
                }
            }
            .onDisappear { pending?.cancel(); tips?.tip = nil }
            .accessibilityLabel(text)
    }
}

extension View {
    /// Hover label that works in the island (see `IslandTipData`); also the accessibility label.
    func islandTip(_ text: String) -> some View { modifier(IslandTipModifier(text: text)) }
}
