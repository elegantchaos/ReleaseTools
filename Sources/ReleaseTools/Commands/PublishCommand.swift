// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 18/04/2019.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Runner

/// Commits and pushes release website changes.
struct PublishCommand: AsyncParsableCommand {
  /// Describes the `publish` command for ArgumentParser.
  static var configuration: CommandConfiguration {
    CommandConfiguration(
      commandName: "publish",
      abstract: "Commit and push any changes made to the website repo."
    )
  }

  @OptionGroup() var website: WebsiteOption
  @OptionGroup() var updates: UpdatesOption
  @OptionGroup() var platform: PlatformOption
  @OptionGroup() var options: CommonOptions

  func run() async throws {
    let engine = try await ReleaseEngine(
      options: options,
      command: Self.configuration,
      platform: platform
    )

    let archive = try engine.requireArchive()
    let git = GitRunner()
    git.cwd = website.websiteURL

    engine.log("Committing updates.")
    var result = git.run(["add", updates.path])
    try await result.throwIfFailed(RunnerError.commitFailed)

    let message = "v\(archive.version), build \(archive.build)"
    result = git.run(["commit", "-a", "-m", message])
    try await result.throwIfFailed(RunnerError.commitFailed)

    engine.log("Pushing updates.")
    let pushResult = git.run(["push"])
    try await pushResult.throwIfFailed(RunnerError.pushFailed)
  }
}

extension PublishCommand {
  /// Failures returned while publishing release updates.
  enum RunnerError: Runner.Error {
    /// Committing the release changes failed.
    case commitFailed
    /// Pushing the release changes failed.
    case pushFailed

    /// Describes the failed git subprocess session.
    func description(for session: Runner.Session) async -> String {
      switch self {
        case .commitFailed: "Failed to commit the appcast feed and updates.\n\n\(await session.stderr.string)"
        case .pushFailed: "Failed to push the appcast feed and updates.\n\n\(await session.stderr.string)"
      }
    }
  }
}
