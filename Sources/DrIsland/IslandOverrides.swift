import Foundation
import DrIslandCore

/// Development aids read from the environment for one launch, on top of the saved settings (mainly for snapshots):
/// `DR_ISLAND_THEME`, `DR_ISLAND_DENSITY`, `DR_ISLAND_STYLE`, `DR_ISLAND_COLUMNS` (1–3) and `DR_ISLAND_SNAPSHOT_DELAY` (seconds, default 3).
enum IslandOverrides {
    // Read once: the environment does not change while the app runs, and views read these on every render.
    private static let env: [String: String] = ProcessInfo.processInfo.environment

    static let theme: IslandTheme? = env["DR_ISLAND_THEME"].flatMap(IslandTheme.init(rawValue:))
    static let density: IslandDensity? = env["DR_ISLAND_DENSITY"].flatMap(IslandDensity.init(rawValue:))
    static let style: IslandStyle? = env["DR_ISLAND_STYLE"].flatMap(IslandStyle.init(rawValue:))
    static let columns: Int? = env["DR_ISLAND_COLUMNS"].flatMap(Int.init).map { min(max($0, 1), IslandLayoutConfig.maxColumns) }
    static let snapshotDelay: Double = env["DR_ISLAND_SNAPSHOT_DELAY"].flatMap(Double.init).map { max($0, 0) } ?? 3
}
