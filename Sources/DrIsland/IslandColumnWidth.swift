import AppKit
import SwiftUI
import DrIslandCore

struct ColumnWidthKey: EnvironmentKey { static let defaultValue: CGFloat = 300 }

extension EnvironmentValues {
    /// Width of the island column a block sits in, so blocks can use extra room instead of just stretching.
    var islandColumnWidth: CGFloat {
        get { self[ColumnWidthKey.self] }
        set { self[ColumnWidthKey.self] = newValue }
    }
}
