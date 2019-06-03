// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 17/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import CommandShell
import Runner

extension Result {
    static let infoUnreadable = Result(400, "Couldn't read archive info.plist.")
    static let compressFailed = Result(401, "Compression failed.")
}

class CompressCommand: Command {
    static let compressedPath = ".build/compressed"

    override var description: Command.Description {
        return Description(
            name: "compress",
            help: "Compress the output of the export command for distribution.",
            usage: ["[[--to=<to>] --latest=<latest>]"],
            options: ["--repo=<repo>": "The repository containing the appcast and updates."],
            returns: [.infoUnreadable]
        )
    }
    
    override func run(shell: Shell) throws -> Result {
        guard let archive = XcodeArchive(url: URL(fileURLWithPath: ArchiveCommand.archivePath)) else {
            return .infoUnreadable
        }

        let exportedAppPath = URL(fileURLWithPath: ExportCommand.exportPath).appendingPathComponent(archive.name)
        let ditto = Runner(for: URL(fileURLWithPath: "/usr/bin/ditto"))
        let archiveFolder = shell.arguments.option("to", default: CompressCommand.compressedPath)
        let destination = URL(fileURLWithPath: archiveFolder).appendingPathComponent(archive.versionedZipName)
        
        shell.log("Compressing \(archive.name) to \(archiveFolder) as \(archive.versionedZipName).")
        let result = try ditto.sync(arguments: ["-c", "-k", "--sequesterRsrc", "--keepParent", exportedAppPath.path, destination.path])
        if result.status != 0 {
            return Result.compressFailed.adding(supplementary: result.stderr)
        }
        
        if let latestFolder = shell.arguments.option("latest") {
            shell.log("Saving copy of archive to \(latestFolder) as \(archive.unversionedZipName).")
            let latestZip = URL(fileURLWithPath: latestFolder).appendingPathComponent(archive.unversionedZipName)
            try? FileManager.default.removeItem(at: latestZip)
            try FileManager.default.copyItem(at: destination, to: latestZip)
        }
        
        return .ok
    }
}
