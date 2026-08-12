// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Thrum",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "spike", path: "Tools/spike")
    ]
)
