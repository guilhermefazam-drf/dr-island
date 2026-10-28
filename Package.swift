// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DrIsland",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "DrIslandCore"),
        .executableTarget(name: "DrIsland", dependencies: ["DrIslandCore"]),
        .testTarget(name: "DrIslandCoreTests", dependencies: ["DrIslandCore"]),
    ]
)
