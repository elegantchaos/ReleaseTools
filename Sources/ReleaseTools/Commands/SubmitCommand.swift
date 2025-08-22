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
  @OptionGroup() var platform: PlatformOption
  @OptionGroup() var options: CommonOptions
  @OptionGroup() var buildOptions: BuildOptions

  func run() async throws {
    let parsed = try OptionParser(
      requires: [.archive],
      options: options,
      command: Self.configuration,
      scheme: scheme,
      platform: platform,
      buildOptions: buildOptions
    )

    // TODO: set scheme if not supplied?
    try await ArchiveCommand.archive(parsed: parsed, xcconfig: xcconfig)
    try await ExportCommand.export(parsed: parsed)
    try await UploadCommand.upload(parsed: parsed)
    // TODO: open page in app portal?
  }
}
