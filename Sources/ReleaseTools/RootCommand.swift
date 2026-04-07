// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 11/10/2018.
//  Copyright © 2018 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Logger
import Runner

/// Root command that's run if no subcommand is specified.
///
/// Handles the `--version` flag, or shows the help if no arguments are provided.
@main
struct RootCommand: AsyncParsableCommand {
  static var configuration: CommandConfiguration {
    CommandConfiguration(
      commandName: "rt",
      abstract: "Assorted tools for iOS/macOS releases.",
      subcommands: [
        AppcastCommand.self,
        ArchiveCommand.self,
        ChangesCommand.self,
        CompressCommand.self,
        ExportCommand.self,
        NotarizeCommand.self,
        PublishCommand.self,
        SubmitCommand.self,
        TagCommand.self,
        UpdateBuildCommand.self,
        UploadCommand.self,
        ValidateCommand.self,
        WaitForNotarizationCommand.self,
      ],
      defaultSubcommand: nil
    )
  }

  @Flag(help: "Show the version.") var version = false

  mutating func run() async throws {
    if version {
      let string = VersionatorVersion.git.contains("-0-") ? VersionatorVersion.tag : VersionatorVersion.git
      print("ReleaseTools \(string).")
    } else {
      throw CleanExit.helpRequest(self)
    }
  }

  public static func main() async {
    do {
      var command = try parseAsRoot(nil)
      if var asyncCommand = command as? AsyncParsableCommand {
        try await asyncCommand.run()
      } else {
        try command.run()
      }
      await Manager.shared.shutdown()
    } catch {
      await Manager.shared.shutdown()
      exit(withError: error)
    }
  }

  /// Error label - adds some extra newlines to separate the error message from the rest of the output.
  public static var _errorLabel: String { "\n\nError" }
}
