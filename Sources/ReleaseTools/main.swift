// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 11/10/2018.
//  All code (c) 2018 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import ArgumentParser
import Runner
import Logger

class Shell {
    var semaphore: DispatchSemaphore? = nil
    var error: Error? = nil
    var showOutput: Bool = false
    
    func log(_ message: String) {
        print(message)
    }
    
}

let sharedShell = Shell()
struct Command: ParsableCommand {
    static var configuration =
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
    
    @Flag(help: "Show the version.") var version = false

    func run() throws {
        if version {
            print(CurrentVersion.git)
        } else {
            throw CleanExit.helpRequest(self)
        }
    }
}

do {
    var command = try Command.parseAsRoot()
    try command.run()
    Logger.defaultManager.flush()
    Command.exit()
} catch {
    Logger.defaultManager.flush()
    Command.exit(withError: error)
}
