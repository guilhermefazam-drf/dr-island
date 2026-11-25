import Foundation

/// An sRGB colour with alpha, kept free of SwiftUI so theme tokens can be tested in the core module.
public struct ThemeColor: Equatable, Sendable {
    public let r: Double
    public let g: Double
    public let b: Double
    public let a: Double

    public init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    /// `0xRRGGBB`, plus an optional alpha.
    public init(_ hex: UInt32, alpha: Double = 1) {
        self.init(r: Double((hex >> 16) & 0xFF) / 255, g: Double((hex >> 8) & 0xFF) / 255, b: Double(hex & 0xFF) / 255, a: alpha)
    }

    /// This colour painted over `base` (source-over), as an opaque colour when `base` is opaque.
    public func over(_ base: ThemeColor) -> ThemeColor {
        let outA = a + base.a * (1 - a)
        guard outA > 0 else { return ThemeColor(r: 0, g: 0, b: 0, a: 0) }
        func mix(_ top: Double, _ bottom: Double) -> Double { (top * a + bottom * base.a * (1 - a)) / outA }
        return ThemeColor(r: mix(r, base.r), g: mix(g, base.g), b: mix(b, base.b), a: outA)
    }

    /// A colour `amount` (0…1) of the way from this one to `other`, channel by channel (alpha too).
    public func mixed(with other: ThemeColor, amount: Double) -> ThemeColor {
        let t = min(max(amount, 0), 1)
        func lerp(_ x: Double, _ y: Double) -> Double { x + (y - x) * t }
        return ThemeColor(r: lerp(r, other.r), g: lerp(g, other.g), b: lerp(b, other.b), a: lerp(a, other.a))
    }

    /// The same colour with another alpha.
    public func withAlpha(_ alpha: Double) -> ThemeColor { ThemeColor(r: r, g: g, b: b, a: min(max(alpha, 0), 1)) }

    /// WCAG 2 relative luminance (alpha ignored).
    public var luminance: Double {
        func channel(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }

    /// WCAG 2 contrast ratio (1…21). A translucent colour is first painted over `other`.
    public func contrast(with other: ThemeColor) -> Double {
        let front = a < 1 ? over(other) : self
        let (l1, l2) = (front.luminance, other.luminance)
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }
}
