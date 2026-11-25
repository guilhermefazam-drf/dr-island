import Foundation

extension IslandPalette {
    /// The palette with the system's accessibility display settings applied.
    /// «Aumentar contraste» moves the secondary texts towards the main one and makes borders and surfaces stronger;
    /// «Reduzir transparência» paints the surfaces opaque over the island's base.
    public func adjusted(increaseContrast: Bool, reduceTransparency: Bool) -> IslandPalette {
        var p = self
        if increaseContrast {
            p.textSecondary = textSecondary.mixed(with: text, amount: 0.5)
            p.textTertiary = textTertiary.mixed(with: text, amount: 0.4)
            p.border = border.withAlpha(min(border.a * 2.2, 1))
            if surface.a < 1 { p.surface = surface.withAlpha(surface.a * 1.6) }
            if surfaceRaised.a < 1 { p.surfaceRaised = surfaceRaised.withAlpha(surfaceRaised.a * 1.5) }
        }
        if reduceTransparency, let bottom = base.last {
            p.surface = p.surface.over(bottom)
            p.surfaceRaised = p.surfaceRaised.over(bottom)
        }
        return p
    }
}
