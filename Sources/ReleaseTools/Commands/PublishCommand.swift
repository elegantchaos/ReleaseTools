// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 18/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Runner

enum PublishError: Runner.Error {
  case commitFailed
  case pushFailed

  func description(for session: Runner.Session) async -> String {
    switch self {
      case .commitFailed:
        return "Failed to commit the appcast feed and updates.\n\n\(await session.stderr.string)"
      case .pushFailed:
        return "Failed to push the appcast feed and updates.\n\n\(await session.stderr.string)"
    }
  }
}

struct PublishCommand: AsyncParsableCommand {
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
    let parsed = try OptionParser(
      requires: [.archive],
      options: options,
      command: Self.configuration,
      platform: platform
    )

    let git = GitRunner()
    git.cwd = website.websiteURL

    parsed.log("Committing updates.")
    var result = git.run(["add", updates.path])
    try await result.throwIfFailed(PublishError.commitFailed)

    let message = "v\(parsed.archive.version), build \(parsed.archive.build)"
    result = git.run(["commit", "-a", "-m", message])
    try await result.throwIfFailed(PublishError.commitFailed)

    parsed.log("Pushing updates.")
    let pushResult = git.run(["push"])
    try await pushResult.throwIfFailed(PublishError.pushFailed)
  }
}
