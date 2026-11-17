// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Lume",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Lume", path: "Sources/Lume")
    ],
    swiftLanguageModes: [.v5]
)
