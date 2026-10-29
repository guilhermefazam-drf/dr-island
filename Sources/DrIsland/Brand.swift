import AppKit
import SwiftUI
import DrIslandCore

/// The Doutor Finanças blue and the macOS window-button colours used across the island.
enum Brand {
    static let blue = Color(red: 0x00 / 255, green: 0xA6 / 255, blue: 0xE5 / 255)
    static let green = Color(red: 0x28 / 255, green: 0xC8 / 255, blue: 0x40 / 255)
    static let amber = Color(red: 0xFE / 255, green: 0xBC / 255, blue: 0x2E / 255)
    static let red = Color(red: 0xFF / 255, green: 0x5F / 255, blue: 0x57 / 255)
}

extension Brand {
    /// The Doutor Finanças logo copied into the bundle by `bundle.sh`; nil when running outside the `.app`.
    static let logo: NSImage? = Bundle.main.url(forResource: "DoutorFinancasLogo", withExtension: "svg").flatMap(NSImage.init(contentsOf:))
}

let linkBlue = Color(red: 0.45, green: 0.68, blue: 1.0)

extension Brand {
    /// Usage colours: green, then amber and red past the user's thresholds (percentages, 0–100).
    static func color(forFraction fraction: Double, amber: Double, red: Double) -> Color {
        switch UsageLevel.level(forFraction: fraction, amber: amber, red: red) {
        case .normal: green
        case .warning: self.amber
        case .critical: self.red
        }
    }
}
