// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 13/02/25.
//  All code (c) 2025 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

extension OptionParser {

  /// Return the build number to use for the next build, and the commit tag it was build from.
  func nextBuildNumberAndCommit(in url: URL, using git: GitRunner) async throws -> (String, String) {
    git.cwd = url
    chdir(url.path)

    // get next build number
    let build = incrementBuildTag ? try await getBuildByIncrementingTag(using: git, platform: platform) : try await getBuildByCommits(using: git, offset: buildOffset)

    // get current commit
    let result = git.run(["rev-list", "--max-count", "1", "HEAD"])
    try await result.throwIfFailed(UpdateBuildError.gettingCommitFailed)
    let commit = await result.stdout.string.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

    return (String(build), commit)
  }

  /// Return the build number to use for the next build.
  /// We calculate the build number by counting the commits in the repo.
  private func getBuildByCommits(using git: GitRunner, offset: UInt) async throws -> UInt {
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
    // make sure the tags are up to date
    let fetchResult = git.run(["fetch", "--tags"])
    try await fetchResult.throwIfFailed(UpdateBuildError.fetchingTagsFailed)

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
