// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 13/12/22.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Runner

/// Archives, exports, and uploads the configured app in one release workflow.
struct SubmitCommand: AsyncParsableCommand {
  /// Describes the `submit` command for ArgumentParser.
  static var configuration: CommandConfiguration {
    CommandConfiguration(
      commandName: "submit",
      abstract: "Archive, export and upload the app to Apple Connect portal for processing."
    )
  }

  @Option(help: "Additional xcconfig file to use when building") var xcconfig: String?
  @OptionGroup() var scheme: SchemeOption
  @OptionGroup() var apiKey: ApiKeyOption
  @OptionGroup() var apiIssuer: ApiIssuerOption
  @OptionGroup() var platform: PlatformOption
  @OptionGroup() var options: CommonOptions

  func run() async throws {
    let engine = try await ReleaseEngine(
      options: options,
      command: Self.configuration,
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
