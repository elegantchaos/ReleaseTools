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
  case fetchingTagsFailed(stderr: String)
  case gettingBuildFailed(stderr: String)
  case gettingCommitFailed
  case parsingCommitFailed
  case writingConfigFailed(stderr: String)
  case updatingIndexFailed(stderr: String)
  case invalidExplicitBuild(String)
  case inconsistentTagState(currentPlatform: String)

  var errorDescription: String? {
    switch self {
      case .fetchingTagsFailed(let stderr):
        return "Failed to fetch tags from git.\n\n\(stderr)"
      case .gettingBuildFailed(let stderr):
        return "Failed to get the build number from git.\n\n\(stderr)"
      case .gettingCommitFailed:
        return "Failed to get the commit from git."
      case .parsingCommitFailed:
        return "Failed to parse the commit information from git."
      case .writingConfigFailed(let stderr):
        return "Failed to write the config file.\n\n\(stderr)"
      case .updatingIndexFailed(let stderr):
        return "Failed to tell git to ignore the config file.\n\n\(stderr)"
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
