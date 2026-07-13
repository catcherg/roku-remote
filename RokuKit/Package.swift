// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "RokuKit",
    platforms: [
        .iOS(.v16),
        .macOS(.v13) // enables `swift test` on macOS CI runners without a simulator
    ],
    products: [
        .library(name: "RokuKit", targets: ["RokuKit"])
    ],
    targets: [
        .target(name: "RokuKit"),
        .testTarget(name: "RokuKitTests", dependencies: ["RokuKit"])
    ]
)
