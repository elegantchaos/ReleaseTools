// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/04/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Testing

@testable import ReleaseTools

/// Tests package discovery and output parsing helpers used by `rt validate`.
struct ValidateCommandDiscoveryTests {
  @Test func recursiveDiscoveryFindsSiblingPackagesAfterBuildArtifacts() throws {
    let repoURL = try makeTemporaryRepo()
    defer { try? FileManager.default.removeItem(at: repoURL) }

    try writePackage(at: repoURL)
    _ = try toolingPaths(config: try parseArgs([]), repoPath: repoURL.path)

    let buildPackageURL = repoURL.appendingPathComponent(".build/rt-validate/DerivedData/BuildArtifact")
    try writePackage(at: buildPackageURL)

    let nestedPackageURL = repoURL.appendingPathComponent("Dependencies/ExamplePackage")
    try writePackage(at: nestedPackageURL)

    let packages = Set(discoverPackageDirs(repoPath: repoURL.path, overrides: nil, recursive: true))

    #expect(packages.contains(repoURL.path))
    #expect(packages.contains(nestedPackageURL.path))
    #expect(packages.contains(buildPackageURL.path) == false)
  }

  @Test func recursiveDiscoverySkipsPackagesUnderTestResources() throws {
    let repoURL = try makeTemporaryRepo()
    defer { try? FileManager.default.removeItem(at: repoURL) }

    try writePackage(at: repoURL)

    let nestedURL = repoURL.appendingPathComponent("Examples/NestedPackage")
    try writePackage(at: nestedURL)

    let fixtureURL = repoURL.appendingPathComponent("Tests/ReleaseToolsTests/Resources/Example-old.package")
    try writePackage(at: fixtureURL)

    let indexBuildPackageURL = repoURL.appendingPathComponent(".index-build/checkouts/Dependency")
    try writePackage(at: indexBuildPackageURL)

    let packages = Set(discoverPackageDirs(repoPath: repoURL.path, overrides: nil, recursive: true))

    #expect(packages.contains(repoURL.path))
    #expect(packages.contains(nestedURL.path))
    #expect(!packages.contains(fixtureURL.path))
    #expect(!packages.contains(indexBuildPackageURL.path))
  }

  @Test func packageDirOverridesCanIncludeFixturePackages() throws {
    let repoURL = try makeTemporaryRepo()
    defer { try? FileManager.default.removeItem(at: repoURL) }

    try writePackage(at: repoURL)

    let fixtureRelativePath = "Tests/ReleaseToolsTests/Resources/Example-old.package"
    let fixtureURL = repoURL.appendingPathComponent(fixtureRelativePath)
    try writePackage(at: fixtureURL)

    let packages = discoverPackageDirs(
      repoPath: repoURL.path,
      overrides: [fixtureRelativePath],
      recursive: true
    )

    #expect(packages == [fixtureURL.path])
  }

  @Test(arguments: [
    ("Tests/FooTests/Resources/Example.package", true),
    ("Tests/Fixtures/Resources/Nested/FixturePackage", true),
    ("Examples/Resources/NestedPackage", false),
    ("Tests/FooTests/Support/HelperPackage", false),
  ])
  func ignoredDiscoveryPaths(path: String, expected: Bool) {
    #expect(shouldIgnoreDiscoveredPackagePath(path) == expected)
  }

  @Test(arguments: [
    (PackageDescription(targets: [TargetInfo(name: "Library", type: "regular")]), false),
    (PackageDescription(targets: [TargetInfo(name: "Library", type: "regular"), TargetInfo(name: "LibraryTests", type: "test")]), true),
  ])
  func packageTestTargetDetection(package: PackageDescription, expected: Bool) {
    #expect(packageHasTestTargets(package) == expected)
  }

  @Test func swiftPMValidationUsesSwiftBuildSystem() {
    #expect(
      swiftPMValidationArguments(["swift", "test", "--filter", "ExampleTests"]) == [
        "swift",
        "test",
        "--filter",
        "ExampleTests",
        "--build-system",
        "swiftbuild",
        "-Xswiftc",
        "-DVALIDATING",
      ]
    )
  }

  @Test(arguments: [
    (["--output", "filtered"], ValidateOutputMode.filtered),
    (["--output", "quiet"], ValidateOutputMode.quiet),
    (["--raw"], ValidateOutputMode.raw),
    (["--quiet"], ValidateOutputMode.quiet),
  ])
  func outputModeParsing(arguments: [String], expected: ValidateOutputMode) throws {
    let config = try parseArgs(arguments)
    #expect(config.outputMode == expected)
  }

  @Test func destinationsDefaultToPlatformDiscovery() throws {
    let config = try parseArgs([])
    #expect(config.destinations.isEmpty)
  }

  @Test func explicitDestinationsArePreserved() throws {
    let config = try parseArgs(["--destinations", "generic/platform=macOS,generic/platform=watchOS"])
    #expect(config.destinations == ["generic/platform=macOS", "generic/platform=watchOS"])
  }

  @Test func buildSettingsDiscoveryUsesRepoLocalDerivedData() {
    #expect(
      xcodeShowBuildSettingsArguments(
        workspace: "App.xcworkspace",
        project: nil,
        scheme: "App",
        derivedDataPath: ".build/rt-validate/DerivedData"
      ) == [
        "xcodebuild",
        "-workspace", "App.xcworkspace",
        "-scheme", "App",
        "-derivedDataPath", ".build/rt-validate/DerivedData",
        "-showBuildSettings",
        "-json",
      ]
    )
  }

  @Test func invalidOutputModeThrows() {
    #expect(throws: CLIError.self) {
      _ = try parseArgs(["--output", "loud"])
    }
  }

  @Test func toolingPathsUseRepoLocalDerivedData() throws {
    let repoURL = try makeTemporaryRepo()
    defer { try? FileManager.default.removeItem(at: repoURL) }

    let staleLogURL = repoURL.appendingPathComponent(".build/validation-logs/stale.log")
    let staleDerivedDataURL = repoURL.appendingPathComponent(".build/rt-validate/DerivedData/stale")
    try FileManager.default.createDirectory(
      at: staleLogURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
      at: staleDerivedDataURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try "old log".write(to: staleLogURL, atomically: true, encoding: .utf8)
    try "old derived data".write(to: staleDerivedDataURL, atomically: true, encoding: .utf8)

    let tools = try toolingPaths(config: try parseArgs(["--clean"]), repoPath: repoURL.path)

    #expect(tools.verifyRoot == repoURL.appendingPathComponent(".build/validation-logs").path)
    #expect(tools.derivedDataPath == repoURL.appendingPathComponent(".build/rt-validate/DerivedData").path)
    #expect(tools.env.isEmpty)
    #expect(FileManager.default.fileExists(atPath: tools.verifyRoot))
    #expect(FileManager.default.fileExists(atPath: tools.derivedDataPath))
    #expect(!FileManager.default.fileExists(atPath: staleLogURL.path))
    #expect(!FileManager.default.fileExists(atPath: staleDerivedDataURL.path))
  }

  @Test(arguments: [
    ("error: cannot find type 'Foo' in scope", "error: cannot find type 'Foo' in scope"),
    ("warning: deprecated API", "warning: deprecated API"),
    ("note: expanded from macro", "note: expanded from macro"),
    ("** BUILD FAILED **", "** BUILD FAILED **"),
    ("remark: compiled module was created by a different version of the compiler", nil),
    ("CompileSwift normal arm64 MyFile.swift", nil),
  ])
  func filteredValidationLineBehavior(line: String, expected: String?) {
    #expect(filteredValidationLine(line) == expected)
  }

  @Test func buildDestinationMapsSupportedSDKPlatforms() {
    #expect(buildDestination(forSupportedPlatform: "macosx") == "generic/platform=macOS")
    #expect(buildDestination(forSupportedPlatform: "iphoneos") == "generic/platform=iOS")
    #expect(buildDestination(forSupportedPlatform: "iphonesimulator") == "generic/platform=iOS")
    #expect(buildDestination(forSupportedPlatform: "appletvos") == "generic/platform=tvOS")
    #expect(buildDestination(forSupportedPlatform: "appletvsimulator") == "generic/platform=tvOS")
    #expect(buildDestination(forSupportedPlatform: "watchos") == "generic/platform=watchOS")
    #expect(buildDestination(forSupportedPlatform: "watchsimulator") == "generic/platform=watchOS")
    #expect(buildDestination(forSupportedPlatform: "xros") == "generic/platform=visionOS")
    #expect(buildDestination(forSupportedPlatform: "xrsimulator") == "generic/platform=visionOS")
    #expect(buildDestination(forSupportedPlatform: "driverkit") == nil)
  }

  @Test func buildDestinationsDecodeSupportedPlatformsFromBuildSettings() throws {
    let output = """
      [
        {
          "buildSettings": {
            "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator"
          }
        },
        {
          "buildSettings": {
            "SUPPORTED_PLATFORMS": "macosx watchos watchsimulator"
          }
        }
      ]
      """

    #expect(
      try buildDestinations(fromBuildSettingsJSON: output) == [
        "generic/platform=iOS",
        "generic/platform=macOS",
        "generic/platform=watchOS",
      ]
    )
  }

  @Test func extractedFailureDiagnosticsPreferErrorBlock() {
    let output = """
      CompileSwift normal arm64 One.swift
      note: candidate found here
      /tmp/One.swift:42:13: error: cannot convert value
      note: expected argument type 'String'
      warning: using deprecated conversion
      ** BUILD FAILED **
      """

    #expect(
      extractedFailureDiagnostics(output) == [
        "note: candidate found here",
        "/tmp/One.swift:42:13: error: cannot convert value",
        "note: expected argument type 'String'",
        "warning: using deprecated conversion",
      ]
    )
  }

  /// Creates a temporary repository root for package discovery tests.
  private func makeTemporaryRepo() throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("ReleaseTools-ValidateDiscovery-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  /// Writes the smallest possible package manifest used by discovery tests.
  private func writePackage(at url: URL) throws {
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    let manifest = url.appendingPathComponent("Package.swift")
    try """
    // swift-tools-version:6.2
    import PackageDescription
    let package = Package(name: "\(url.lastPathComponent)")
    """
    .write(to: manifest, atomically: true, encoding: .utf8)
  }
}
