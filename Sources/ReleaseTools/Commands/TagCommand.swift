// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 08/10/25.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Runner

/// Creates a version tag for the current git revision.
struct TagCommand: AsyncParsableCommand {
  /// Describes the `tag` command for ArgumentParser.
  static var configuration: CommandConfiguration {
    CommandConfiguration(
      commandName: "tag",
      abstract: "Create a version tag at HEAD if one doesn't exist."
    )
  }

  @Option(help: "The version to use for the tag (e.g., 1.2.3). If not specified, will try to determine from project files.") var explicitVersion: String?
  @Option(help: "Explicit build number to use for the tag.") var explicitBuild: String?

  @OptionGroup() var options: CommonOptions

  func run() async throws {
    let engine = try await ReleaseEngine(
      options: options,
      command: Self.configuration
    )

    // Check if there's already a version tag at HEAD
    try await engine.ensureNoExistingTag()

    // Get or determine the version
    let version = try await getVersion(engine: engine)

    // Get the build number (either explicit or calculated)
    let build: UInt
    if let explicitBuild {
      guard let explicitBuildNumber = UInt(explicitBuild) else {
        throw ReleaseEngine.Error.invalidExplicitBuild(explicitBuild)
      }
      engine.verbose("Using explicit build number: \(explicitBuildNumber)")
      build = explicitBuildNumber
    } else {
      // Calculate the build number (platform-agnostic)
      build = try await engine.nextPlatformAgnosticBuildNumber()
    }

    // Get current commit
    let commit = try await engine.git.headCommit()

    // Create the tag in format: v<version>-<build>
    let tagName = "v\(version)-\(build)"

    engine.log("Creating tag: \(tagName) at commit \(commit)")

    let tagResult = engine.git.run(["tag", tagName, commit])
    try await tagResult.throwIfFailed(Error.creatingTagFailed)

    engine.log("Successfully created tag: \(tagName)")
  }

  /// Get the version string, either from the --explicit-version option or from the highest existing tag
  private func getVersion(engine: ReleaseEngine) async throws -> String {
    if let tagVersion = explicitVersion {
      return tagVersion
    }

    // Try to get version from the highest existing tag
    if let version = try await engine.versionFromHighestTag() {
      engine.verbose("Found version from highest tag: \(version)")
      return version
    }

    // Fall back to 1.0.0 if no tags exist
    engine.verbose("No existing tags found, using default version: 1.0.0")
    return "1.0.0"
  }
}

extension TagCommand {
  /// Errors emitted while creating a version tag.
  enum Error: Swift.Error, LocalizedError {
    /// Creating the git tag failed.
    case creatingTagFailed

    /// A user-facing description of the failure.
    var errorDescription: String? {
      switch self {
        case .creatingTagFailed: return "Failed to create the git tag."
      }
    }
  }
}
