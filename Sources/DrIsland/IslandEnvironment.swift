import SwiftUI
import DrIslandCore

private struct IslandPaletteKey: EnvironmentKey { static let defaultValue = IslandTheme.grafite.palette }
private struct IslandMetricsKey: EnvironmentKey { static let defaultValue = IslandMetrics.forDensity(.regular) }

extension EnvironmentValues {
    /// The colour tokens of the island's theme; island views use these instead of literal colours.
    var islandPalette: IslandPalette {
        get { self[IslandPaletteKey.self] }
        set { self[IslandPaletteKey.self] = newValue }
    }

    /// The sizes for the island's density (card padding, row height, type…).
    var islandMetrics: IslandMetrics {
        get { self[IslandMetricsKey.self] }
        set { self[IslandMetricsKey.self] = newValue }
    }
}

extension Color {
    init(_ token: ThemeColor) {
        self.init(.sRGB, red: token.r, green: token.g, blue: token.b, opacity: token.a)
    }
}
