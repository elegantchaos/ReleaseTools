// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 11/10/2018.
//  All code (c) 2018 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import ArgumentParser
import Runner

struct Shell {
    func log(_ message: String) {
        print(message)
    }
}

let sharedShell = Shell()

extension ParsableCommand {
    
    var shell: Shell {
        return sharedShell
    }
}

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
                InstallCommand.self,
                NotarizeCommand.self,
                PublishCommand.self,
                UpdateBuildCommand.self,
                UploadCommand.self,
                WaitForNotarizationCommand.self,
            ],
            defaultSubcommand: nil
    )
}

Command.main()
