// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "generate-tiers",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../../Packages/EconomyKit")
    ],
    targets: [
        .executableTarget(
            name: "generate-tiers",
            dependencies: [.product(name: "EconomyKit", package: "EconomyKit")]
        )
    ]
)
