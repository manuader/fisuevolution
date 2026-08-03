// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "pacing-sim",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../../Packages/EconomyKit")
    ],
    targets: [
        .executableTarget(
            name: "pacing-sim",
            dependencies: [.product(name: "EconomyKit", package: "EconomyKit")]
        )
    ]
)
