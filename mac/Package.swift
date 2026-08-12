// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Thrum",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "ThrumCore"),
        .target(name: "ThrumHaptics", dependencies: ["ThrumCore"]),
        .target(name: "ThrumPlayback", dependencies: ["ThrumCore", "ThrumHaptics"]),
        .executableTarget(name: "spike", path: "Tools/spike"),
        .testTarget(name: "ThrumCoreTests", dependencies: ["ThrumCore", "ThrumHaptics", "ThrumPlayback"])
    ]
)
