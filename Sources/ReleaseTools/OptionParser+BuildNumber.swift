// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 13/02/25.
//  All code (c) 2025 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

extension OptionParser {

  /// Get the build number and commit from an existing platform-agnostic version tag at HEAD
  func buildNumberAndCommit(requireHeadTag: Bool = true) async throws -> (String, String) {
    if requireHeadTag {
      let build = try await versionTagAtHEAD().build

      // Get the commit SHA
      let commitResult = git.run(["rev-parse", "HEAD"])
      let commitOutput = await commitResult.stdout.string
      let commitState = await commitResult.waitUntilExit()
      guard case .succeeded = commitState else {
        throw UpdateBuildError.gettingCommitFailed
      }
      guard let commit = commitOutput.split(separator: "\n").first else {
        throw UpdateBuildError.parsingCommitFailed
      }

      return (build, commit.trimmingCharacters(in: .whitespacesAndNewlines))
    } else {
      // New behavior: calculate build number from highest existing tag + 1
      // Get the commit SHA first
      let commitResult = git.run(["rev-parse", "HEAD"])
      let commitOutput = await commitResult.stdout.string
      let commitState = await commitResult.waitUntilExit()
      guard case .succeeded = commitState else {
        throw UpdateBuildError.gettingCommitFailed
      }
      guard let commit = commitOutput.split(separator: "\n").first else {
        throw UpdateBuildError.parsingCommitFailed
      }

      // Calculate the next build number
      let buildNumber = try await nextPlatformAgnosticBuildNumber()

      return (String(buildNumber), commit.trimmingCharacters(in: .whitespacesAndNewlines))
    }
  }

  /// Fetch all version tags, extract platform as String and build as UInt, and process each with the provided closure if both are non-nil.
  private func processAllVersionTags(
    process: @escaping (_ platform: String, _ build: UInt, _ tag: String) async -> Void
  ) async throws {
    let pattern: Regex<(Substring, version: Substring, Substring?, build: Substring, platform: Substring)> = #/^v(?<version>\d+\.\d+(\.\d+)*)-(?<build>\d+)-(?<platform>.*)$/#
    let tagsResult = git.run(["tag"])
    try await tagsResult.throwIfFailed(UpdateBuildError.gettingBuildFailed)
    for await tag in await tagsResult.stdout.lines {
      if let parsed = tag.firstMatch(of: pattern) {
        let platform = String(parsed.output.platform)
        if let build = UInt(parsed.output.build) {
          await process(platform, build, tag)
        }
      }
    }
  }

  /// Fetch all platform-agnostic version tags (format: v<version>-<build>), and process each with the provided closure.
  func processAllPlatformAgnosticVersionTags(
    process: @escaping (_ build: UInt, _ tag: String) async -> Void
  ) async throws {
    let pattern: Regex<(Substring, version: Substring, Substring?, build: Substring)> = #/^v(?<version>\d+\.\d+(\.\d+)*)-(?<build>\d+)$/#
    let tagsResult = git.run(["tag"])
    try await tagsResult.throwIfFailed(UpdateBuildError.gettingBuildFailed)
    for await tag in await tagsResult.stdout.lines {
      if let parsed = tag.firstMatch(of: pattern) {
        if let build = UInt(parsed.output.build) {
          await process(build, tag)
        }
      }
    }
  }

  /// Calculate build number for platform-agnostic tags.
  /// Returns the highest existing build number + 1, or 1 if no tags exist.
  /// Also checks platform-specific tags to ensure we don't create duplicate build numbers.
  func nextPlatformAgnosticBuildNumber() async throws -> UInt {
    await ensureTagsUpToDate(using: git)

    var maxBuild: UInt = 0
    var maxTag: String?
    var isPlatformSpecific = false

    // Check platform-agnostic tags
    try await processAllPlatformAgnosticVersionTags { build, tag in
      if build > maxBuild {
        maxBuild = build
        maxTag = tag
        isPlatformSpecific = false
      }
    }

    // Also check platform-specific tags to avoid conflicts
    try await processAllVersionTags { platform, build, tag in
      if build > maxBuild {
        maxBuild = build
        maxTag = tag
        isPlatformSpecific = true
      }
    }

    if let maxTag {
      if isPlatformSpecific {
        log("Highest existing tag was \(maxTag) (converting from platform-specific to platform-agnostic tags).")
      } else {
        log("Highest existing tag was \(maxTag).")
      }
    } else {
      log("No existing tags found.")
    }

    return maxBuild + 1
  }

  /// Get the platform-agnostic version tag at HEAD.
  /// Returns the tag and build number from the tag.
  /// Throw an error if one is not found.
  func versionTagAtHEAD() async throws -> (tag: String, build: String) {

    // Get tags pointing at HEAD
    let result = git.run(["tag", "--points-at", "HEAD"])
    let state = await result.waitUntilExit()
    guard case .succeeded = state else {
      throw GeneralError.noVersionTagAtHEAD
    }

    // Look for platform-agnostic version tags: v<version>-<build>
    let pattern = #/^v(?<version>\d+\.\d+(\.\d+)*)-(?<build>\d+)$/#

    for await line in await result.stdout.lines {
      let tag = line.trimmingCharacters(in: .whitespacesAndNewlines)
      if let match = tag.firstMatch(of: pattern) {
        let build = String(match.build)
        verbose("Found version tag at HEAD: \(tag) with build \(build)")
        return (tag, build)
      }
    }

    throw GeneralError.noVersionTagAtHEAD
  }

  /// Get the version string from the highest existing tag.
  /// Returns the version (e.g., "1.2.3") or nil if no tags exist.
  func versionFromHighestTag() async throws -> String? {
    await ensureTagsUpToDate(using: git)

    var highestVersion: String?
    var highestBuild: UInt = 0

    // Check platform-agnostic tags first
    let agnosticPattern = #/^v(?<version>\d+\.\d+(\.\d+)*)-(?<build>\d+)$/#
    try await processAllPlatformAgnosticVersionTags { build, tag in
      if build > highestBuild {
        if let match = tag.firstMatch(of: agnosticPattern) {
          highestVersion = String(match.version)
          highestBuild = build
        }
      }
    }

    // Also check platform-specific tags
    let specificPattern = #/^v(?<version>\d+\.\d+(\.\d+)*)-(?<build>\d+)-(?<platform>.*)$/#
    try await processAllVersionTags { _, build, tag in
      if build > highestBuild {
        if let match = tag.firstMatch(of: specificPattern) {
          highestVersion = String(match.version)
          highestBuild = build
        }
      }
    }

    return highestVersion
  }

  /// Ensure tags are up-to-date by fetching from remote, ignoring failures if no remote exists.
  private func ensureTagsUpToDate(using git: GitRunner) async {
    let fetchResult = git.run(["fetch", "--tags"])
    let fetchState = await fetchResult.waitUntilExit()
    if case .failed(_) = fetchState {
      // Ignore fetch failures (e.g., no remote configured) and continue with local tags
    }
  }
}
