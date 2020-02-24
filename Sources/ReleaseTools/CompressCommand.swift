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
            usage: ["--to=<to> --latest=<latest>"],
            options: ["--repo=<repo>": "The repository containing the appcast and updates."],
            returns: [.infoUnreadable]
        )
    }
    
    override func run(shell: Shell) throws -> Result {
        guard let archive = archive else {
            return Result.infoUnreadable.adding(supplementary: archiveURL.path)
        }

        let exportedAppURL = exportURL.appendingPathComponent(archive.name)
        let ditto = DittoRunner(shell: shell)
        let archiveFolder = try shell.arguments.expectedOption("to")
        let destination = URL(fileURLWithPath: archiveFolder).appendingPathComponent(archive.versionedZipName)
        
        let result = try ditto.zip(exportedAppURL, as: destination)
        if result.status != 0 {
            return Result.exportFailed.adding(supplementary: result.stderr)
        }
        
        let latestFolder = try shell.arguments.expectedOption("latest")
        shell.log("Saving copy of archive to \(latestFolder) as \(archive.unversionedZipName).")
        let latestZip = URL(fileURLWithPath: latestFolder).appendingPathComponent(archive.unversionedZipName)
        try? FileManager.default.removeItem(at: latestZip)
        try FileManager.default.copyItem(at: destination, to: latestZip)
        
        return .ok
    }
}
