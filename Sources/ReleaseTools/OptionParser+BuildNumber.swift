// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 13/02/25.
//  All code (c) 2025 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation

extension OptionParser {

  /// Return the build number to use for the next build, and the commit tag it was build from.
  func nextBuildNumberAndCommit(in url: URL, using git: GitRunner) async throws -> (String, String) {
    git.cwd = url
    // Avoid changing global process CWD; rely on Runner.cwd

    // get next build number
    let build: UInt
    if let explicitBuild {
      // use explicitly specified build number
      guard let explicitBuildNumber = UInt(explicitBuild) else {
        throw ValidationError("Invalid explicit build number: \(explicitBuild). Must be a positive integer.")
      }
      build = explicitBuildNumber
      verbose("Using explicit build number: \(build)")
    } else {
  // optionally use the build number from an existing tag for another platform
      var adoptedBuild: UInt? = nil
      if useExistingTag {
        adoptedBuild = try await getBuildFromExistingTag(using: git, currentPlatform: platform)
        if let adoptedBuild {
          verbose("Adopting build number from another platform tag: \(adoptedBuild)")
        }
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
    // ensure tags are up-to-date (skip if no remote exists)
    let fetchResult = git.run(["fetch", "--tags"])
    let fetchState = await fetchResult.waitUntilExit()
    if case .failed(_) = fetchState {
      // Ignore fetch failures (e.g., no remote configured) and continue with local tags
    }

    // get all tags
    let tagsResult = git.run(["tag"])
    try await tagsResult.throwIfFailed(UpdateBuildError.gettingBuildFailed)

    let pattern = #/^v(?<version>\d+\.\d+(\.\d+)*)-(?<build>\d+)-(?<platform>.*)$/#
    var maxAny: UInt = 0
    var maxCurrent: UInt = 0
    for await tag in await tagsResult.stdout.lines {
      if let parsed = tag.firstMatch(of: pattern), let build = UInt(parsed.build) {
        if build > maxAny { maxAny = build }
        if parsed.platform == currentPlatform, build > maxCurrent { maxCurrent = build }
      }
    }

    if maxAny > maxCurrent {
      return maxAny
    } else if maxAny == maxCurrent && maxAny > 0 {
      return maxAny + 1
    } else if maxAny < maxCurrent {
      throw ValidationError("Inconsistent tag state: highest build for platform (\(currentPlatform)) is greater than highest build for any platform. This should not happen. Please check your tags.")
    } else if maxCurrent > 0 {
      return maxCurrent
    } else {
      return nil
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
    // make sure the tags are up to date (skip if no remote exists)
    let fetchResult = git.run(["fetch", "--tags"])
    let fetchState = await fetchResult.waitUntilExit()
    if case .failed(_) = fetchState {
      // Ignore fetch failures (e.g., no remote configured) and continue with local tags
    }

    // get highest existing build in any version tag for this platform
    let pattern = #/^v(?<version>\d+\.\d+(\.\d+)*)-(?<build>\d+)-(?<platform>.*)$/#
    let tagsResult = git.run(["tag"])
    try await tagsResult.throwIfFailed(UpdateBuildError.gettingBuildFailed)
    var maxBuild: UInt = 0
    var maxTag: String?
    for await tag in await tagsResult.stdout.lines {
      if let parsed = tag.firstMatch(of: pattern) {
        if parsed.platform == platform, let build = UInt(parsed.build) {
          if build > maxBuild {
            maxBuild = build
            maxTag = tag
          }
        }
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
}
