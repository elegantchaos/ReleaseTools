// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 19/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import ChaosByteStreams
import Files
import Foundation
import Resources
import Runner

enum UpdateBuildError: Runner.Error {
  case fetchingTagsFailed
  case gettingBuildFailed
  case gettingCommitFailed
  case writingConfigFailed
  case updatingIndexFailed
  case invalidExplicitBuild(String)
  case inconsistentTagState(currentPlatform: String)

  func description(for session: Runner.Session) async -> String {
    async let stderr = session.stderr.string
    switch self {
      case .fetchingTagsFailed: return "Failed to fetch tags from git.\n\n\(await stderr)"
      case .gettingBuildFailed: return "Failed to get the build number from git.\n\n\(await stderr)"
      case .gettingCommitFailed: return "Failed to get the commit from git.\n\n\(await stderr)"
      case .writingConfigFailed: return "Failed to write the config file.\n\n\(await stderr)"
      case .updatingIndexFailed: return "Failed to tell git to ignore the config file.\n\n\(await stderr)"
      case .invalidExplicitBuild(let value):
        return "Invalid explicit build number: \(value). Must be a positive integer."
      case .inconsistentTagState(let currentPlatform):
        return "Inconsistent tag state: highest build for platform (\(currentPlatform)) is greater than highest build for any platform. This should not happen. Please check your tags."
    }
  }
}

struct UpdateBuildCommand: AsyncParsableCommand {
  static var configuration: CommandConfiguration {
    CommandConfiguration(
      commandName: "update-build",
      abstract: "Update an .xcconfig file to contain the latest build number."
    )
  }

  @Option(help: "The .xcconfig file to update.") var config: String?
  @Option(help: "The header file to generate.") var header: String?
  @Option(help: "The .plist file to update.") var plist: String?
  @Option(help: "The .plist file to update.") var plistDest: String?
  @Option(help: "The git repo to derive the build number from.") var repo: String?

  @OptionGroup() var options: CommonOptions

  func run() async throws {
    let parsed = try OptionParser(
      options: options,
      command: Self.configuration
    )

    if let header = header, let repo = repo {
      _ = try await Generation.generateHeader(parsed: parsed, header: header, repo: repo)
    } else if let plist = plist, let dest = plistDest, let repo = repo {
      try await Generation.generatePlist(parsed: parsed, source: plist, dest: dest, repo: repo)
    } else {
      try await Generation.generateConfig(parsed: parsed, config: config)
    }
  }

}
