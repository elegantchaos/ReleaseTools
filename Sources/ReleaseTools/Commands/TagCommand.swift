// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 08/10/2025.
//  Copyright © 2025 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Runner

/// Creates a version tag for the current git revision.
struct TagCommand: AsyncParsableCommand {
  /// Version string supplied instead of inferring it from existing tags.
  @Option(help: "The version to use for the tag (e.g., 1.2.3). If not specified, uses the version from the highest existing tag.") var explicitVersion: String?

  /// Build number supplied instead of calculating the next one.
  @Option(help: "Explicit build number to use for the tag.") var explicitBuild: String?

  /// Shared workspace and diagnostic flags for this command.
  @OptionGroup() var options: CommonOptions

  /// Describes the `tag` command for ArgumentParser.
  static var configuration: CommandConfiguration {
    CommandConfiguration(
      commandName: "tag",
      abstract: "Create a version tag at HEAD if one doesn't exist."
    )
  }

  /// Validates HEAD and creates a version tag using explicit or calculated metadata.
  func run() async throws {
    let engine = try await ReleaseEngine(options: options)

    try await engine.ensureNoExistingTag()

    let version = try await getVersion(engine: engine)

    let build: UInt
    if let explicitBuild {
      guard let explicitBuildNumber = UInt(explicitBuild) else {
        throw ReleaseEngine.Error.invalidExplicitBuild(explicitBuild)
      }
      engine.verbose("Using explicit build number: \(explicitBuildNumber)")
      build = explicitBuildNumber
    } else {
      build = try await engine.nextPlatformAgnosticBuildNumber()
    }

    let commit = try await engine.git.headCommit()

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

    if let version = try await engine.versionFromHighestTag() {
      engine.verbose("Found version from highest tag: \(version)")
      return version
    }

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
