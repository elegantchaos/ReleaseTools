// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 13/02/25.
//  All code (c) 2025 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

extension OptionParser {

  /// Return the build number to use for the next build, and the commit tag it was build from.
  func nextBuildNumberAndCommit(in url: URL, using git: GitRunner) async throws -> (String, String) {
    git.cwd = url

    // get next build number
    let build: UInt
    if let explicitBuild {
      // use explicitly specified build number
      guard let explicitBuildNumber = UInt(explicitBuild) else {
        throw UpdateBuildError.invalidExplicitBuild(explicitBuild)
      }
      build = explicitBuildNumber
      verbose("Using explicit build number: \(build)")
    } else {
      // optionally use the build number from an existing tag for another platform
      var adoptedBuild: UInt? = nil
      if useExistingTag {
        adoptedBuild = try await getBuildFromExistingTag(using: git, currentPlatform: platform)
      }

      if let adoptedBuild {
        build = adoptedBuild
      } else if incrementBuildTag {
        build = try await getBuildByIncrementingTag(using: git, platform: platform)
      } else {
        build = try await getBuildByCommitCount(using: git, offset: buildOffset)
      }
    }

    // get current commit
    let result = git.run(["rev-list", "--max-count", "1", "HEAD"])
    try await result.throwIfFailed(UpdateBuildError.gettingCommitFailed)
    let commit = await result.stdout.string.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

    return (String(build), commit)
  }

  /// Find the highest build number for any platform and for the current platform.
  /// If the highest for any platform is greater than the current platform, use it.
  /// If they are equal, increment it. Otherwise, use the current platform's max.
  private func getBuildFromExistingTag(using git: GitRunner, currentPlatform: String) async throws -> UInt? {
    await ensureTagsUpToDate(using: git)

    var maxAny: UInt = 0
    var maxCurrent: UInt = 0
    var maxTag: String?
    var maxPlatformTag: String?

    try await processAllVersionTags(using: git) { platform, build, tag in
      if build > maxAny {
        maxAny = build
        maxTag = tag
      }

      if platform == currentPlatform, build > maxCurrent {
        maxCurrent = build
        maxPlatformTag = tag
      }
    }

    guard maxAny >= maxCurrent else {
      // something is wrong if the max for the current platform is greater than the max for any platform
      throw UpdateBuildError.inconsistentTagState(currentPlatform: currentPlatform)
    }

    guard maxAny > 0 else {
      // no existing tags at all
      return nil
    }

    if maxAny > maxCurrent {
      verbose("Adopting build number \(maxAny) from another platform tag: \(maxTag!).")
      return maxAny
    } else {
      let result = maxCurrent + 1
      verbose("Highest tag \(maxPlatformTag!) was from this platform, so incrementing the build number to \(result).")
      return result
    }
  }

  /// Return the build number to use for the next build.
  /// We calculate the build number by counting the commits in the repo.
  private func getBuildByCommitCount(using git: GitRunner, offset: UInt) async throws -> UInt {
    let result = git.run(["rev-list", "--count", "HEAD"])
    try await result.throwIfFailed(UpdateBuildError.gettingBuildFailed)

    let count = await result.stdout.string.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    let build = (UInt(count) ?? 1) + offset

    return build
  }

  /// Return the build number to use for the next build.
  /// We calculate the build number by searching the repo tags for the
  /// highest existing build number, and adding 1 to it.
  private func getBuildByIncrementingTag(using git: GitRunner, platform: String) async throws -> UInt {
    await ensureTagsUpToDate(using: git)

    var maxBuild: UInt = 0
    var maxTag: String?
    try await processAllVersionTags(using: git) { tagPlatform, build, tag in
      if tagPlatform == platform, build > maxBuild {
        maxBuild = build
        maxTag = tag
      }
    }

    if let maxTag {
      log("Highest existing tag for \(platform) was \(maxTag).")
    } else {
      log("No existing tags found for \(platform).")
    }

    // add 1 for the new build number
    return maxBuild + 1
  }

  /// Fetch all version tags, extract platform as String and build as UInt, and process each with the provided closure if both are non-nil.
  private func processAllVersionTags(
    using git: GitRunner,
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
}

/// Ensure tags are up-to-date by fetching from remote, ignoring failures if no remote exists.
private func ensureTagsUpToDate(using git: GitRunner) async {
  let fetchResult = git.run(["fetch", "--tags"])
  let fetchState = await fetchResult.waitUntilExit()
  if case .failed(_) = fetchState {
    // Ignore fetch failures (e.g., no remote configured) and continue with local tags
  }
}
