// swift-tools-version:4.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ReleaseTools",
    products: [
        .executable(name: "rt", targets: ["ReleaseTools"]),
    ],
    dependencies: [
        .package(url: "https://github.com/elegantchaos/Runner.git", from: "1.0.2"),
        .package(url: "https://github.com/elegantchaos/CommandShell.git", from: "1.0.4"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "ReleaseTools",
            dependencies: ["CommandShell", "Runner"]),
        .testTarget(
            name: "ReleaseToolsTests",
            dependencies: ["ReleaseTools"]),
    ]
)
