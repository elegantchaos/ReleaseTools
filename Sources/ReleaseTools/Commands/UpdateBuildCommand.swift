// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 19/04/2019.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import ChaosByteStreams
import Files
import Foundation
import Runner

/// Updates build metadata files from the current release history.
struct UpdateBuildCommand: AsyncParsableCommand {
  /// Describes the `update-build` command for ArgumentParser.
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
    let engine = try await ReleaseEngine(
      options: options,
      command: Self.configuration
    )

    if let header = header {
      _ = try await engine.generateHeader(header: header, requireHEADTag: false)
    } else if let plist = plist, let dest = plistDest {
      try await engine.generatePlist(source: plist, dest: dest)
    } else {
      try await engine.generateConfig(config: config)
    }
  }
}
