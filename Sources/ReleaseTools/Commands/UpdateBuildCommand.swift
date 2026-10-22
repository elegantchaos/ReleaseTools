// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 19/04/2019.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Files
import Foundation
import Runner

/// Updates build metadata files from the current release history.
struct UpdateBuildCommand: AsyncParsableCommand {
  /// Optional path for generated Xcode build settings.
  @Option(help: "The .xcconfig file to update.") var config: String?

  /// Optional path for a generated version header.
  @Option(help: "The header file to generate.") var header: String?

  /// Source property list to update with calculated build metadata.
  @Option(help: "The .plist file to update.") var plist: String?

  /// Destination for the generated property list.
  @Option(help: "The .plist file to update.") var plistDest: String?

  /// Shared workspace and diagnostic flags for this command.
  @OptionGroup() var options: CommonOptions

  /// Describes the `update-build` command for ArgumentParser.
  static var configuration: CommandConfiguration {
    CommandConfiguration(
      commandName: "update-build",
      abstract: "Update an .xcconfig file to contain the latest build number."
    )
  }

  /// Writes the requested version header, Xcode settings, and property list.
  func run() async throws {
    let engine = try await ReleaseEngine(options: options)

    if let header = header {
      _ = try await engine.generateHeader(header: header, requireHEADTag: false)
    } else if let plist = plist, let dest = plistDest {
      try await engine.generatePlist(source: plist, dest: dest)
    } else {
      try await engine.generateConfig(config: config)
    }
  }
}
