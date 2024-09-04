// swift-tools-version:6.0

import PackageDescription

let package = Package(
  name: "ReleaseTools",

  platforms: [
    .macOS(.v13)
  ],

  products: [
    .executable(name: "rt", targets: ["ReleaseTools"]),
    .library(name: "Resources", targets: ["Resources"]),
    .plugin(name: "rt-plugin", targets: ["ReleaseToolsPlugin"]),
  ],

  dependencies: [
    .package(url: "https://github.com/elegantchaos/Coercion.git", from: "1.1.2"),
    .package(url: "https://github.com/elegantchaos/Files.git", from: "1.2.0"),
    .package(url: "https://github.com/elegantchaos/Logger.git", branch: "v2-wip"),
    .package(url: "https://github.com/elegantchaos/Runner.git", from: "2.0.10"),
    .package(url: "https://github.com/elegantchaos/ChaosByteStreams", from: "1.0.0"),
    .package(url: "https://github.com/elegantchaos/Versionator.git", from: "2.0.2"),
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
  ],

  targets: [
    .executableTarget(
      name: "ReleaseTools",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "ChaosByteStreams", package: "ChaosByteStreams"),
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

    .plugin(
      name: "ReleaseToolsPlugin",
      capability: .command(
        intent: .custom(
          verb: "rt",
          description: "Manages archiving and uploading releases."
        ),
        permissions: [
          .writeToPackageDirectory(reason: "Builds and archives releases.")
        ]
      ),

      dependencies: [
        "ReleaseTools"
      ]
    ),

    .testTarget(
      name: "ReleaseToolsTests",
      dependencies: ["ReleaseTools"]
    ),
  ]
)
