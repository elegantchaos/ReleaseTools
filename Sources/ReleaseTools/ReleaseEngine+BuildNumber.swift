// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 13/02/25.
//  All code (c) 2025 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

extension ReleaseEngine {

  /// Pattern for platform-agnostic version tags: v<version>-<build> (e.g., v1.2.3-42)
  private nonisolated(unsafe) static let platformAgnosticTagPattern: Regex<(Substring, version: Substring, Substring?, build: Substring)> =
    #/^v(?<version>\d+\.\d+(\.\d+)*)-(?<build>\d+)$/#

  /// Pattern for platform-specific version tags: v<version>-<build>-<platform> (e.g., v1.2.3-42-iOS)
  private nonisolated(unsafe) static let platformSpecificTagPattern: Regex<(Substring, version: Substring, Substring?, build: Substring, platform: Substring)> =
    #/^v(?<version>\d+\.\d+(\.\d+)*)-(?<build>\d+)-(?<platform>.*)$/#

  /// Information about a build including build number, commit hash, and version string
  struct BuildInfo {
    /// The build number (e.g., 42)
    let build: UInt
    /// The full commit hash (e.g., "f13a5c4e2bde037cafdc8706abbd7e93013b2102")
    let commit: String
    /// The semantic version string (e.g., "1.2.3")
    let version: String
  }

  /// Get build information including build number, commit hash, and version string
  /// - Parameter requireHeadTag: If true, requires a version tag at HEAD and extracts info from it.
  ///                           If false, calculates next build number and uses version from highest existing tag.
  func buildInfoFromTag(requireHeadTag: Bool = true) async throws -> BuildInfo {
    if requireHeadTag {
      // versionTagAtHEAD already returns complete BuildInfo with all parsed information
      return try await versionTagAtHEAD()
    } else {
      // For incremental builds, we need to calculate the next build number
      let commit = try await git.headCommit()
      let build = try await nextPlatformAgnosticBuildNumber()
      let version = try await versionFromHighestTag() ?? "1.0.0"
      return BuildInfo(build: build, commit: commit, version: version)
    }
  }

  /// Fetch all version tags, extract platform as String and build as UInt, and process each with the provided closure if both are non-nil.
  private func processAllVersionTags(
    process: @escaping (_ platform: String, _ build: UInt, _ tag: String) async -> Void
  ) async throws {
    let tagsResult = git.run(["tag"])
    try await tagsResult.throwIfFailed(UpdateBuildError.gettingBuildFailed)
    for await tag in await tagsResult.stdout.lines {
      if let parsed = tag.firstMatch(of: Self.platformSpecificTagPattern) {
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
    let tagsResult = git.run(["tag"])
    try await tagsResult.throwIfFailed(UpdateBuildError.gettingBuildFailed)
    for await tag in await tagsResult.stdout.lines {
      if let parsed = tag.firstMatch(of: Self.platformAgnosticTagPattern) {
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
  /// Returns BuildInfo with build number, commit hash, and version from the tag.
  /// Throw an error if one is not found.
  func versionTagAtHEAD() async throws -> BuildInfo {

    // Get tags pointing at HEAD
    let result = git.run(["tag", "--points-at", "HEAD"])
    let state = await result.waitUntilExit()
    guard case .succeeded = state else {
      throw GeneralError.noVersionTagAtHEAD
    }

    let commit = try await git.headCommit()

    for await line in await result.stdout.lines {
      let tag = line.trimmingCharacters(in: .whitespacesAndNewlines)
      if let match = tag.firstMatch(of: Self.platformAgnosticTagPattern) {
        let build = UInt(match.build) ?? 0
        let version = String(match.version)
        verbose("Found version tag at HEAD: \(tag) with build \(build)")
        return BuildInfo(build: build, commit: commit, version: version)
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
    try await processAllPlatformAgnosticVersionTags { build, tag in
      if build > highestBuild {
        if let match = tag.firstMatch(of: Self.platformAgnosticTagPattern) {
          highestVersion = String(match.version)
          highestBuild = build
        }
      }
    }

    // Also check platform-specific tags
    try await processAllVersionTags { _, build, tag in
      if build > highestBuild {
        if let match = tag.firstMatch(of: Self.platformSpecificTagPattern) {
          highestVersion = String(match.version)
          highestBuild = build
        }
      }
    }

    return highestVersion
  }

  /// Check if there's already a version tag at HEAD and throw an error if found
  func ensureNoExistingTag() async throws {
    do {
      let info = try await versionTagAtHEAD()
      throw TagError.tagAlreadyExists(info)
    } catch GeneralError.noVersionTagAtHEAD {
      // This is what we want - no existing tag
      return
    }
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
