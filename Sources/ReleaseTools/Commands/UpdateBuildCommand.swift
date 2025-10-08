// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 19/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import ChaosByteStreams
import Files
import Foundation
import Runner

enum UpdateBuildError: LocalizedError {
  case fetchingTagsFailed(Runner.Session)
  case gettingBuildFailed(Runner.Session)
  case gettingCommitFailed
  case parsingCommitFailed
  case writingConfigFailed(String)
  case updatingIndexFailed(Runner.Session)
  case invalidExplicitBuild(String)
  case inconsistentTagState(currentPlatform: String)

  var errorDescription: String? {
    get async {
      switch self {
        case .fetchingTagsFailed(let session):
          return "Failed to fetch tags from git.\n\n\(await session.stderr.string)"
        case .gettingBuildFailed(let session):
          return "Failed to get the build number from git.\n\n\(await session.stderr.string)"
        case .gettingCommitFailed:
          return "Failed to get the commit from git."
        case .parsingCommitFailed:
          return "Failed to parse the commit information from git."
        case .writingConfigFailed(let errorMsg):
          return "Failed to write the config file.\n\n\(errorMsg)"
        case .updatingIndexFailed(let session):
          return "Failed to tell git to ignore the config file.\n\n\(await session.stderr.string)"
        case .invalidExplicitBuild(let value):
          return "Invalid explicit build number: \(value). Must be a positive integer."
        case .inconsistentTagState(let currentPlatform):
          return "Inconsistent tag state: highest build for platform (\(currentPlatform)) is greater than highest build for any platform. This should not happen. Please check your tags."
      }
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

  @OptionGroup() var options: CommonOptions

  func run() async throws {
    let parsed = try OptionParser(
      options: options,
      command: Self.configuration
    )

    if let header = header {
      _ = try await Generation.generateHeader(parsed: parsed, header: header, requireHEADTag: false)
    } else if let plist = plist, let dest = plistDest {
      try await Generation.generatePlist(parsed: parsed, source: plist, dest: dest)
    } else {
      try await Generation.generateConfig(parsed: parsed, config: config)
    }
  }

}
