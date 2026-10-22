// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 13/12/2022.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Runner

/// Archives, exports, and uploads the configured app in one release workflow.
struct SubmitCommand: AsyncParsableCommand {
  /// Optional build settings file passed to Xcode.
  @Option(help: "Additional xcconfig file to use when building") var xcconfig: String?

  /// Scheme selection supplied on the command line.
  @OptionGroup() var scheme: SchemeOption

  /// App Store Connect API key selection.
  @OptionGroup() var apiKey: ApiKeyOption

  /// App Store Connect API issuer selection.
  @OptionGroup() var apiIssuer: ApiIssuerOption

  /// Target platform supplied on the command line.
  @OptionGroup() var platform: PlatformOption

  /// Shared workspace and diagnostic flags for this command.
  @OptionGroup() var options: CommonOptions

  /// Describes the `submit` command for ArgumentParser.
  static var configuration: CommandConfiguration {
    CommandConfiguration(
      commandName: "submit",
      abstract: "Archive, export and upload the app to Apple Connect portal for processing."
    )
  }

  /// Archives, exports, and uploads the selected application in sequence.
  func run() async throws {
    let engine = try await ReleaseEngine(
      options: options,
      scheme: scheme,
      apiKey: apiKey,
      apiIssuer: apiIssuer,
      platform: platform
    )

    try await ArchiveCommand.archive(engine: engine, xcconfig: xcconfig)
    try await ExportCommand.export(engine: engine)
    try await UploadCommand.upload(engine: engine)
  }
}
