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
    let build = countCommits ? try await getBuildByCommits(using: git, offset: buildOffset) : try await getBuildSequential(using: git, platform: platform)

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
  private func getBuildSequential(using git: GitRunner, platform: String) async throws -> UInt {
    // get highest existing build in any version tag for this platform
    let pattern = #/^v(?<version>\d+\.\d+(\.\d+)*)-(?<build>\d+)-(?<platform>.*)$/#
    let result = git.run(["tag"])
    try await result.throwIfFailed(UpdateBuildError.gettingBuildFailed)
    var maxBuild: UInt = 0
    for await tag in await result.stdout.lines {
      if let parsed = tag.firstMatch(of: pattern) {
        if parsed.platform == platform, let build = UInt(parsed.build) {
          maxBuild = max(maxBuild, build)
        }
      }
    }

    // add 1 for the new build number
    return maxBuild + 1
  }
}
