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
    try await result.throwIfFailed(Error.commitFailed)

    let message = "v\(archive.version), build \(archive.build)"
    result = git.run(["commit", "-a", "-m", message])
    try await result.throwIfFailed(Error.commitFailed)

    engine.log("Pushing updates.")
    let pushResult = git.run(["push"])
    try await pushResult.throwIfFailed(Error.pushFailed)
  }
}

extension PublishCommand {
  /// Errors emitted while publishing release updates.
  enum Error: Swift.Error, LocalizedError {
    /// Committing the release changes failed.
    case commitFailed
    /// Pushing the release changes failed.
    case pushFailed

    /// A user-facing description of the failure.
    var errorDescription: String? {
      switch self {
        case .commitFailed: return "Failed to commit the appcast feed and updates."
        case .pushFailed: return "Failed to push the appcast feed and updates."
      }
    }
  }
}
