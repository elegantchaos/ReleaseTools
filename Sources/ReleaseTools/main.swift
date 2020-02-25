// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 11/10/2018.
//  All code (c) 2018 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import CommandShell
import Runner

extension Result {
    func adding(runnerResult: Runner.Result) -> Result {
        return adding(supplementary: [runnerResult.stdout, runnerResult.stderr].joined(separator: "\n\n"))
    }
}

let shell = Shell(commands: [
    AppcastCommand(),
    ArchiveCommand(),
    CompressCommand(),
    ExportCommand(),
    InstallCommand(),
    NotarizeCommand(),
    PublishCommand(),
    UpdateBuildCommand(),
    UploadCommand(),
    WaitForNotarizationCommand(),
    ]
)

shell.run()
