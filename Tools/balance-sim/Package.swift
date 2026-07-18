// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "balance-sim",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../../Packages/EconomyKit")
    ],
    targets: [
        .executableTarget(
            name: "balance-sim",
            dependencies: [.product(name: "EconomyKit", package: "EconomyKit")]
        )
    ]
)
