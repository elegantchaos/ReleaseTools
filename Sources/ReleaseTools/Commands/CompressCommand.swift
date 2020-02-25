// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 17/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import CommandShell
import Runner

class CompressCommand: RTCommand {
    override var description: Command.Description {
        return Description(
            name: "compress",
            help: "Compress the output of the export command for distribution.",
            usage: ["[\(websiteOption)] [\(updatesOption)]"],
            options: [
                showOutputOption: showOutputOptionHelp,
                updatesOption: updatesOptionHelp,
                websiteOption: websiteOptionHelp,
            ],
            returns: [.infoUnreadable]
        )
    }
    
    override func run(shell: Shell) throws -> Result {
        let gotRequirements = require([.archive])
        guard gotRequirements == .ok else {
            return gotRequirements
        }

        let stapledAppURL = stapledURL.appendingPathComponent(archive.name)
        let ditto = DittoRunner(shell: shell)
        let destination = updatesURL.appendingPathComponent(archive.versionedZipName)
        
        let result = try ditto.zip(stapledAppURL, as: destination)
        if result.status != 0 {
            return Result.exportFailed.adding(supplementary: result.stderr)
        }
        
        shell.log("Saving copy of archive to \(websiteURL.path) as \(archive.unversionedZipName).")
        let latestZip = websiteURL.appendingPathComponent(archive.unversionedZipName)
        try? FileManager.default.removeItem(at: latestZip)
        try FileManager.default.copyItem(at: destination, to: latestZip)
        
        return .ok
    }
}
