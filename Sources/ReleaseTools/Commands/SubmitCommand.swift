// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 13/12/22.
//  All code (c) 2022 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Runner

/// Performs the following commands in order:
/// - archive
/// - export
/// - upload

struct SubmitCommand: AsyncParsableCommand {

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
    let engine = try ReleaseEngine(
      options: options,
      command: Self.configuration,
      scheme: scheme,
      apiKey: apiKey,
      apiIssuer: apiIssuer,
      platform: platform
    )

    try await ArchiveCommand.archive(engine: engine, xcconfig: xcconfig)
    try await ExportCommand.export(engine: engine)
    engine.archive = XcodeArchive(url: engine.archiveURL)
    try await UploadCommand.upload(engine: engine)
    // TODO: open page in app portal?
  }
}
