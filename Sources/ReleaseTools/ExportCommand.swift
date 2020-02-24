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
            usage: ["[<scheme> [--set-default] [--show-build]]"],
            options: [
                "--show-build" : "show build command and output"
            ],
            returns: [.exportFailed]
        )
    }
    
    override func run(shell: Shell) throws -> Result {
        let xcode = XcodeRunner(shell: shell)
        guard let workspace = defaultWorkspace else {
            return .missingWorkspace
        }

        guard let scheme = scheme(for: workspace, shell: shell) else {
            return Result.noDefaultScheme.adding(supplementary: "Set using \(CommandLine.name) \(description.name) <scheme> --set-default.")
        }

        if shell.arguments.flag("set-default") {
            setDefaultScheme(scheme, for: workspace)
        }

        let exportOptionsPath = "Sources/\(scheme)/Resources/Export Options.plist"

        shell.log("Exporting \(scheme).")
        try? FileManager.default.removeItem(at: exportURL)
        let result = try xcode.run(arguments: ["-exportArchive", "-archivePath", archiveURL.path, "-exportPath", exportURL.path, "-exportOptionsPlist", exportOptionsPath, "-allowProvisioningUpdates"])
        if result.status == 0 {
            return .ok
        } else {
            return Result.exportFailed.adding(supplementary: result.stderr)
        }
    }
}
