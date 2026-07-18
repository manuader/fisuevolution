// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EconomyKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "EconomyKit", targets: ["EconomyKit"])
    ],
    targets: [
        .target(name: "EconomyKit"),
        .testTarget(name: "EconomyKitTests", dependencies: ["EconomyKit"]),
    ]
)
