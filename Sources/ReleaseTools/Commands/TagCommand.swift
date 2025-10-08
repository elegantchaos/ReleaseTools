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
    async let stderr = session.stderr.string
    switch self {
      case .tagAlreadyExists(let tag):
        return "A version tag already exists at HEAD: \(tag)"
      case .gettingVersionFailed:
        return "Failed to get the version information.\n\n\(await stderr)"
      case .gettingBuildFailed:
        return "Failed to calculate the build number.\n\n\(await stderr)"
      case .creatingTagFailed:
        return "Failed to create the git tag.\n\n\(await stderr)"
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

  @Option(help: "The version to use for the tag (e.g., 1.2.3). If not specified, will try to determine from project files.") var tagVersion: String?
  @Option(help: "Explicit build number to use for the tag.") var explicitBuild: String?

  @OptionGroup() var options: CommonOptions

  func run() async throws {
    let parsed = try OptionParser(
      options: options,
      command: Self.configuration
    )

    // Check if there's already a version tag at HEAD
    try await ensureNoExistingTag(parsed: parsed)

    // Get or determine the version
    let version = try await getVersion(parsed: parsed)

    // Get the build number (either explicit or calculated)
    let build: UInt
    if let explicitBuild {
      guard let explicitBuildNumber = UInt(explicitBuild) else {
        throw UpdateBuildError.invalidExplicitBuild(explicitBuild)
      }
      parsed.verbose("Using explicit build number: \(explicitBuildNumber)")
      build = explicitBuildNumber
    } else {
      // Calculate the build number (platform-agnostic)
      build = try await parsed.nextPlatformAgnosticBuildNumber()
    }

    // Get current commit
    let commitResult = parsed.git.run(["rev-list", "--max-count", "1", "HEAD"])
    try await commitResult.throwIfFailed(TagError.gettingBuildFailed)
    let commit = await commitResult.stdout.string.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

    // Create the tag in format: v<version>-<build>
    let tagName = "v\(version)-\(build)"

    parsed.log("Creating tag: \(tagName) at commit \(commit)")

    let tagResult = parsed.git.run(["tag", tagName, commit])
    try await tagResult.throwIfFailed(TagError.creatingTagFailed)

    parsed.log("Successfully created tag: \(tagName)")
  }

  /// Check if there's already a version tag at HEAD and throw an error if found
  private func ensureNoExistingTag(parsed: OptionParser) async throws {
    // Get tags pointing at HEAD
    let result = parsed.git.run(["tag", "--points-at", "HEAD"])
    let state = await result.waitUntilExit()

    guard case .succeeded = state else {
      // If we can't check tags, continue anyway
      return
    }

    let pattern = #/^v\d+\.\d+(\.\d+)*-\d+$/#

    for await line in await result.stdout.lines {
      let tag = line.trimmingCharacters(in: .whitespacesAndNewlines)
      if tag.firstMatch(of: pattern) != nil {
        throw TagError.tagAlreadyExists(tag)
      }
    }
  }

  /// Get the version string, either from the --version option or from the highest existing tag
  private func getVersion(parsed: OptionParser) async throws -> String {
    if let tagVersion = tagVersion {
      return tagVersion
    }

    // Try to get version from the highest existing tag
    if let version = try await parsed.versionFromHighestTag() {
      parsed.verbose("Found version from highest tag: \(version)")
      return version
    }

    // Fall back to 1.0.0 if no tags exist
    parsed.verbose("No existing tags found, using default version: 1.0.0")
    return "1.0.0"
  }
}
