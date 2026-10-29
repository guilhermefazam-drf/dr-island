import SwiftUI
import DrIslandCore

extension PRChange.Tone {
    var color: Color {
        switch self {
        case .critical: return Color(red: 0xFF / 255, green: 0x5F / 255, blue: 0x57 / 255)
        case .warning: return Color(red: 0xFE / 255, green: 0xBC / 255, blue: 0x2E / 255)
        case .info: return Color(red: 0.36, green: 0.62, blue: 1.0)
        case .success: return Color(red: 0x28 / 255, green: 0xC8 / 255, blue: 0x40 / 255)
        case .neutral: return .gray
        }
    }
}
