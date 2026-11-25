import Foundation

/// The island's colour themes. Grafite reproduces the island's original colours.
public enum IslandTheme: String, CaseIterable, Codable, Sendable {
    case grafite
    case meiaNoite = "meia-noite"
    case aurora
    case claro

    /// The stored setting, or Grafite when it is missing or unknown.
    public init(stored: String?) {
        self = stored.flatMap(IslandTheme.init(rawValue:)) ?? .grafite
    }

    public var title: String {
        switch self {
        case .grafite: "Grafite"
        case .meiaNoite: "Meia-noite"
        case .aurora: "Aurora"
        case .claro: "Claro"
        }
    }

    public var palette: IslandPalette {
        switch self {
        case .grafite:
            IslandPalette(
                base: [ThemeColor(0x000000)], collar: ThemeColor(0x000000),
                surface: ThemeColor(0xFFFFFF, alpha: 0.055), surfaceRaised: ThemeColor(0xFFFFFF, alpha: 0.09),
                border: ThemeColor(0xFFFFFF, alpha: 0), highlight: ThemeColor(0xFFFFFF, alpha: 0),
                text: ThemeColor(0xF3F3F5), textSecondary: ThemeColor(0xA1A1AA), textTertiary: ThemeColor(0x6C6C75),
                accent: ThemeColor(0x00A6E5), green: ThemeColor(0x28C840), amber: ThemeColor(0xFEBC2E), red: ThemeColor(0xFF5F57),
                purple: ThemeColor(0xBF8BFF), pink: ThemeColor(0xFF6B9A), orange: ThemeColor(0xFF9F5A), info: ThemeColor(0x5C9EFF), neutral: ThemeColor(0x8E8E93), isLight: false)
        case .meiaNoite:
            IslandPalette(
                base: [ThemeColor(0x060A14), ThemeColor(0x0A1224)], collar: ThemeColor(0x060A14),
                surface: ThemeColor(0x6EA0FF, alpha: 0.07), surfaceRaised: ThemeColor(0x6EA0FF, alpha: 0.12),
                border: ThemeColor(0x8CB4FF, alpha: 0.12), highlight: ThemeColor(0xA0C8FF, alpha: 0.08),
                text: ThemeColor(0xEDF2FF), textSecondary: ThemeColor(0x98A6C4), textTertiary: ThemeColor(0x64718F),
                accent: ThemeColor(0x3FC0FF), green: ThemeColor(0x3DDC84), amber: ThemeColor(0xFFCF4A), red: ThemeColor(0xFF6B6B),
                purple: ThemeColor(0xA99BFF), pink: ThemeColor(0xFF7EB3), orange: ThemeColor(0xFFA564), info: ThemeColor(0x5CB0FF), neutral: ThemeColor(0x8A96B0), isLight: false)
        case .aurora:
            IslandPalette(
                base: [ThemeColor(0x0A0A10)], collar: ThemeColor(0x0A0A10),
                surface: ThemeColor(0xFFFFFF, alpha: 0.06), surfaceRaised: ThemeColor(0xFFFFFF, alpha: 0.10),
                border: ThemeColor(0xFFFFFF, alpha: 0.10), highlight: ThemeColor(0xFFFFFF, alpha: 0.10),
                text: ThemeColor(0xF6F4FF), textSecondary: ThemeColor(0xAAA5C2), textTertiary: ThemeColor(0x716C8A),
                accent: ThemeColor(0x9D8CFF), green: ThemeColor(0x4CE0A0), amber: ThemeColor(0xFFD166), red: ThemeColor(0xFF6B81),
                purple: ThemeColor(0xC3A6FF), pink: ThemeColor(0xFF8FC7), orange: ThemeColor(0xFFB37A), info: ThemeColor(0x8FA8FF), neutral: ThemeColor(0x8E8AA6), isLight: false)
        case .claro:
            IslandPalette(
                base: [ThemeColor(0xF2F3F6)], collar: ThemeColor(0x000000),
                surface: ThemeColor(0xFFFFFF), surfaceRaised: ThemeColor(0xF0F2F5),
                border: ThemeColor(0x0F141E, alpha: 0.08), highlight: ThemeColor(0xFFFFFF),
                text: ThemeColor(0x15171C), textSecondary: ThemeColor(0x5B616D), textTertiary: ThemeColor(0x8D939E),
                accent: ThemeColor(0x0088C2), green: ThemeColor(0x1F9D46), amber: ThemeColor(0xB7791F), red: ThemeColor(0xD6322B),
                purple: ThemeColor(0x7C4DD6), pink: ThemeColor(0xD63D74), orange: ThemeColor(0xD0661F), info: ThemeColor(0x2F6FDB), neutral: ThemeColor(0x80868F), isLight: true)
        }
    }
}
