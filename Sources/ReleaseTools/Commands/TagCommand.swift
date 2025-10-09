// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 08/10/25.
//  All code (c) 2025 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Runner

enum TagError: Runner.Error {
  case tagAlreadyExists(String)
  case gettingVersionFailed
  case gettingBuildFailed
  case creatingTagFailed

  func description(for session: Runner.Session) async -> String {
    switch self {
      case .tagAlreadyExists(let tag):
        return "A version tag already exists at HEAD: \(tag)"
      case .gettingVersionFailed:
        return "Failed to get the version information.\n\n\(await session.stderr.string)"
      case .gettingBuildFailed:
        return "Failed to calculate the build number.\n\n\(await session.stderr.string)"
      case .creatingTagFailed:
        return "Failed to create the git tag.\n\n\(await session.stderr.string)"
    }
  }
}

struct TagCommand: AsyncParsableCommand {
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
    let engine = try ReleaseEngine(
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
        throw UpdateBuildError.invalidExplicitBuild(explicitBuild)
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
    try await tagResult.throwIfFailed(TagError.creatingTagFailed)

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
