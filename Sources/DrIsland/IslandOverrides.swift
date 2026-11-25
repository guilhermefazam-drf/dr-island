import Foundation
import DrIslandCore

/// Development aids read from the environment for one launch, on top of the saved settings (mainly for snapshots):
/// `DR_ISLAND_THEME`, `DR_ISLAND_DENSITY`, `DR_ISLAND_COLUMNS` (1–3) and `DR_ISLAND_SNAPSHOT_DELAY` (seconds, default 3).
enum IslandOverrides {
    private static var env: [String: String] { ProcessInfo.processInfo.environment }

    static var theme: IslandTheme? { env["DR_ISLAND_THEME"].flatMap(IslandTheme.init(rawValue:)) }
    static var density: IslandDensity? { env["DR_ISLAND_DENSITY"].flatMap(IslandDensity.init(rawValue:)) }
    static var columns: Int? { env["DR_ISLAND_COLUMNS"].flatMap(Int.init).map { min(max($0, 1), IslandLayoutConfig.maxColumns) } }
    static var snapshotDelay: Double { env["DR_ISLAND_SNAPSHOT_DELAY"].flatMap(Double.init).map { max($0, 0) } ?? 3 }
}
