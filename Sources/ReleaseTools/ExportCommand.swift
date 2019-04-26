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

class ExportCommand: Command {
    static let exportPath = ".build/export"
    
    override var description: Command.Description {
        return Description(
            name: "export",
            help: "Export an executable from the output of the archive command.",
            usage: ["[<scheme> [--set-default]]"],
            returns: [.exportFailed]
        )
    }
    
    override func run(shell: Shell) throws -> Result {
        let xcode = XcodeRunner()
        guard let workspace = xcode.defaultWorkspace else {
            return .missingWorkspace
        }

        guard let scheme = xcode.scheme(for: workspace, shell: shell) else {
            return Result.noDefaultScheme.adding(supplementary: "Set using \(CommandLine.name) \(description.name) <scheme> --set-default.")
        }

        if shell.arguments.flag("set-default") {
            xcode.setDefaultScheme(scheme, for: workspace)
        }

        let exportPath = ExportCommand.exportPath
        let exportOptionsPath = "Sources/\(scheme)/Resources/Export Options.plist"

        shell.log("Exporting \(scheme).")
        try? FileManager.default.removeItem(atPath: exportPath)
        let result = try xcode.sync(arguments: ["-exportArchive", "-archivePath", ArchiveCommand.archivePath, "-exportPath", exportPath, "-exportOptionsPlist", exportOptionsPath, "-allowProvisioningUpdates"])
        if result.status == 0 {
            return .ok
        } else {
            return Result.exportFailed.adding(supplementary: result.stderr)
        }
    }
}
