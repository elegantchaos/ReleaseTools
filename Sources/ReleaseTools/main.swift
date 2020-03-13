// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 11/10/2018.
//  All code (c) 2018 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import ArgumentParser
import Runner

class Shell {
    var semaphore: DispatchSemaphore? = nil
    var error: Error? = nil
    var showOutput: Bool = false
    
    func log(_ message: String) {
        print(message)
    }
    
}

let sharedShell = Shell()

extension Runner.Result: CustomStringConvertible {
    public var description: String {
        return [stdout, stderr].joined(separator: "\n\n")
    }
}

struct Command: ParsableCommand {
    static var configuration =
        CommandConfiguration(
            abstract: "Test program.",
            discussion: "Some blurb about the program.",
            subcommands: [
                AppcastCommand.self,
                ArchiveCommand.self,
                CompressCommand.self,
                ExportCommand.self,
                GetCommand.self,
                InstallCommand.self,
                NotarizeCommand.self,
                PublishCommand.self,
                SetCommand.self,
                UnsetCommand.self,
                UpdateBuildCommand.self,
                UploadCommand.self,
                WaitForNotarizationCommand.self,
            ],
            defaultSubcommand: nil
    )
    
    @Flag(help: "Show the version.") var version: Bool

    func run() throws {
        if version {
            print(Metadata.main.version)
        } else {
            throw CleanExit.helpRequest(self)
        }
    }
}

Command.main()
