// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 13/12/22.
//  All code (c) 2022 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Runner

import protocol ArgumentParser.AsyncParsableCommand

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

  @OptionGroup() var scheme: SchemeOption
  @OptionGroup() var user: UserOption
  @OptionGroup() var platform: PlatformOption
  @OptionGroup() var options: CommonOptions

  func run() async throws {
    let parsed = try OptionParser(
      requires: [.archive],
      options: options,
      command: Self.configuration,
      scheme: scheme,
      user: user,
      platform: platform
    )

    // TODO: set scheme if not supplied?
    try await ArchiveCommand.archive(parsed: parsed)
    try await ExportCommand.export(parsed: parsed)
    try await UploadCommand.upload(parsed: parsed)
    // TODO: open page in app portal?
  }
}
