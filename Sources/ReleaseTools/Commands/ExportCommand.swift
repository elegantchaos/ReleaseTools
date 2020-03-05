// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 17/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Arguments
import CommandShell
import Foundation

extension Result {
    static let exportFailed = Result(300, "Exporting failed.")
}

class ExportCommand: RTCommand {
    
    override var description: Command.Description {
        return Description(
            name: "export",
            help: "Export an executable from the output of the archive command.",
            usage: ["[\(schemeOption) [\(setDefaultOption)]] [\(showOutputOption)] [\(platformOption)]"],
            options: [
                platformOption: platformOptionHelp,
                schemeOption: schemeOptionHelp,
                setDefaultOption: setDefaultOptionHelp,
                showOutputOption : showOutputOptionHelp,
            ],
            returns: [.exportFailed]
        )
    }
    
    override func run(shell: Shell) throws -> Result {
        let xcode = XCodeBuildRunner(shell: shell)
        
        let gotRequirements = require([.package, .workspace, .scheme])
        guard gotRequirements == .ok else {
            return gotRequirements
        }

        shell.log("Exporting \(scheme).")
        try? FileManager.default.removeItem(at: exportURL)
        let result = try xcode.run(arguments: ["-exportArchive", "-archivePath", archiveURL.path, "-exportPath", exportURL.path, "-exportOptionsPlist", exportOptionsURL.path, "-allowProvisioningUpdates"])
        if result.status == 0 {
            return .ok
        } else {
            return Result.exportFailed.adding(supplementary: result.stderr)
        }
    }
}
