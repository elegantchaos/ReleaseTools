// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "ReleaseTools",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(name: "rt", targets: ["ReleaseTools"]),
    ],
    dependencies: [
        .package(url: "https://github.com/elegantchaos/Runner.git", from: "1.0.5"),
        .package(url: "https://github.com/elegantchaos/CommandShell.git", from: "1.1.3"),
    ],
    targets: [
        .target(
            name: "ReleaseTools",
            dependencies: ["CommandShell", "Runner"]),
        .testTarget(
            name: "ReleaseToolsTests",
            dependencies: ["ReleaseTools"]),
    ]
)
