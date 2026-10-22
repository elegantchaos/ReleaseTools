// swift-tools-version:6.2

// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 17/04/2019.
//  Copyright © 2019 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import PackageDescription

/// Defines the release executable, its dependencies, and integration test target.
let package = Package(
  name: "ReleaseTools",

  platforms: [
    .macOS(.v26)
  ],

  products: [
    .executable(name: "rt", targets: ["ReleaseTools"])
  ],

  dependencies: [
    .package(url: "https://github.com/apple/swift-configuration", from: "1.2.0"),
    .package(url: "https://github.com/elegantchaos/Coercion.git", from: "1.1.2"),
    .package(url: "https://github.com/elegantchaos/Files.git", from: "1.2.0"),
    .package(url: "https://github.com/elegantchaos/Logger.git", from: "2.0.0"),
    .package(url: "https://github.com/elegantchaos/Runner.git", from: "2.2.0"),
    .package(url: "https://github.com/elegantchaos/Versionator.git", from: "2.0.3"),
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
  ],

  targets: [
    .executableTarget(
      name: "ReleaseTools",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "Configuration", package: "swift-configuration"),
        "Coercion",
        "Files",
        "Logger",
        "Runner",
      ],
      plugins: [
        .plugin(name: "VersionatorPlugin", package: "Versionator")
      ]
    ),

    .testTarget(
      name: "ReleaseToolsTests",
      dependencies: [
        .target(name: "ReleaseTools")
      ]
    ),
  ]
)
