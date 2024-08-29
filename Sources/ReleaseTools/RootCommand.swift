// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 11/10/2018.
//  All code (c) 2018 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Logger
import Runner

// class Shell {
//   var semaphore: DispatchSemaphore? = nil
//   var error: Error? = nil
//   var showOutput: Bool = false

//   func log(_ message: String) {
//     print(message)
//   }

// }

// let sharedShell = Shell()

@main
struct RootCommand: AsyncParsableCommand {
  static var configuration: CommandConfiguration {
    CommandConfiguration(
      abstract: "Assorted tools for iOS/macOS releases.",
      subcommands: [
        AppcastCommand.self,
        ArchiveCommand.self,
        BootstrapCommand.self,
        ChangesCommand.self,
        CompressCommand.self,
        ExportCommand.self,
        GetCommand.self,
        InstallCommand.self,
        NotarizeCommand.self,
        PublishCommand.self,
        SetCommand.self,
        SubmitCommand.self,
        UnsetCommand.self,
        UpdateBuildCommand.self,
        UploadCommand.self,
        WaitForNotarizationCommand.self,
      ],
      defaultSubcommand: nil
    )
  }

  @Flag(help: "Show the version.") var version = false

  mutating func run() async throws {
    if version {
      print("Release tools \(VersionatorVersion.git)")
    } else {
      throw CleanExit.helpRequest(self)
    }
    Logger.defaultManager.flush()
  }
}

// do {
//   var command = try Command.parseAsRoot()
//   try command.run()
//   Logger.defaultManager.flush()
//   Command.exit()
// } catch {
//   Logger.defaultManager.flush()
//   Command.exit(withError: error)
// }
