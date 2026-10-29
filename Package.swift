// swift-tools-version:5.9
import PackageDescription

// Full data-race checking (the Swift 6 rules as warnings) while the package stays in Swift 5 mode.
let strictConcurrency: [SwiftSetting] = [.enableExperimentalFeature("StrictConcurrency")]

let package = Package(
    name: "DrIsland",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "DrIslandCore", swiftSettings: strictConcurrency),
        .executableTarget(name: "DrIsland", dependencies: ["DrIslandCore"], swiftSettings: strictConcurrency),
        .testTarget(name: "DrIslandCoreTests", dependencies: ["DrIslandCore"], swiftSettings: strictConcurrency),
    ]
)
