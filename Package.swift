// swift-tools-version:6.0

import PackageDescription

let package = Package(
  name: "ReleaseTools",

  platforms: [
    .macOS(.v12)
  ],

  products: [
    .executable(name: "rt", targets: ["ReleaseTools"]),
    .library(name: "Resources", targets: ["Resources"]),
  ],

  dependencies: [
    .package(url: "https://github.com/elegantchaos/Coercion.git", from: "1.1.2"),
    .package(url: "https://github.com/elegantchaos/Files.git", from: "1.2.0"),
    .package(url: "https://github.com/elegantchaos/Logger.git", from: "1.6.0"),
    .package(url: "https://github.com/elegantchaos/Runner.git", from: "2.0.5"),
    .package(url: "https://github.com/elegantchaos/XCTestExtensions.git", from: "1.3.0"),
    .package(url: "https://github.com/elegantchaos/Versionator.git", from: "2.0.2"),
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
  ],

  targets: [
    .executableTarget(
      name: "ReleaseTools",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        "Coercion",
        "Files",
        "Logger",
        "Runner",
        "Resources",
      ],
      plugins: [
        .plugin(name: "VersionatorPlugin", package: "Versionator")
      ]
    ),

    .target(
      name: "Resources",
      dependencies: [
        "Files"
      ],
      resources: [
        .copy("Scripts")
      ]
    ),

    .testTarget(
      name: "ReleaseToolsTests",
      dependencies: ["ReleaseTools", "XCTestExtensions"]
    ),
  ]
)
