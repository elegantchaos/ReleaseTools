// swift-tools-version:5.2

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
        .package(url: "https://github.com/apple/swift-argument-parser", from: "0.0.2"),
        .package(url: "https://github.com/elegantchaos/BuilderConfiguration.git", from: "1.1.4"),
        .package(url: "https://github.com/elegantchaos/Logger.git", from: "1.5.3"),
        .package(url: "https://github.com/elegantchaos/Runner.git", from: "1.0.5"),
        .package(url: "https://github.com/elegantchaos/URLExtensions.git", from: "1.0.1"),
        .package(url: "https://github.com/elegantchaos/XCTestExtensions.git", from: "1.0.9"),
    ],
    targets: [
        .target(
            name: "ReleaseTools",
            dependencies: [
                "Logger",
                "Runner",
                "URLExtensions",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]),
        .target(
            name: "Configure",
            dependencies: ["BuilderConfiguration"]),
        .testTarget(
            name: "ReleaseToolsTests",
            dependencies: ["ReleaseTools", "XCTestExtensions"]),
    ]
)
