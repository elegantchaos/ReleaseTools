// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 18/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Runner

import protocol ArgumentParser.AsyncParsableCommand

enum PublishError: Error {
  case commitFailed(_ result: Runner.RunningProcess)
  case pushFailed(_ result: Runner.RunningProcess)

  public var description: String {
    switch self {
    case .commitFailed(let result):
      return "Failed to commit the appcast feed and updates.\n\(result)"
    case .pushFailed(let result): return "Failed to push the appcast feed and updates.\n\(result)"
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
    var result = try git.run(["add", updates.path])
    try await result.throwIfFailed(PublishError.commitFailed(result))

    let message = "v\(parsed.archive.version), build \(parsed.archive.build)"
    result = try git.run(["commit", "-a", "-m", message])
    try await result.throwIfFailed(PublishError.commitFailed(result))

    parsed.log("Pushing updates.")
    let pushResult = try git.run(["push"])
    try await pushResult.throwIfFailed(PublishError.pushFailed(pushResult))
  }
}
