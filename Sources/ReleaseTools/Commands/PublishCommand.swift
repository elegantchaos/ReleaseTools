// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 18/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Runner

enum PublishError: LocalizedError {
  case commitFailed(stderr: String)
  case pushFailed(stderr: String)

  var errorDescription: String? {
    switch self {
      case .commitFailed(let stderr):
        return "Failed to commit the appcast feed and updates.\n\n\(stderr)"
      case .pushFailed(let stderr):
        return "Failed to push the appcast feed and updates.\n\n\(stderr)"
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
    var state = await result.waitUntilExit()
    if case .failed = state {
      let stderr = await result.stderr.string
      throw PublishError.commitFailed(stderr: stderr)
    }

    let message = "v\(parsed.archive.version), build \(parsed.archive.build)"
    result = git.run(["commit", "-a", "-m", message])
    state = await result.waitUntilExit()
    if case .failed = state {
      let stderr = await result.stderr.string
      throw PublishError.commitFailed(stderr: stderr)
    }

    parsed.log("Pushing updates.")
    let pushResult = git.run(["push"])
    state = await pushResult.waitUntilExit()
    if case .failed = state {
      let stderr = await pushResult.stderr.string
      throw PublishError.pushFailed(stderr: stderr)
    }
  }
}
