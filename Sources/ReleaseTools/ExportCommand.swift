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
    
    override var name: String { return "export" }
    
    override var usage: String { return "release export" }

    override func run(shell: Shell) throws -> Result {
        let xcode = XcodeRunner()
        guard let workspace = xcode.defaultWorkspace else {
            return .missingWorkspace
        }

        guard let scheme = xcode.scheme(for: workspace, shell: shell) else {
            var result = Result.noDefaultScheme
            result.supplementary = "Set using \(CommandLine.name) \(name) <scheme> --set-default."
            return result
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
            var returnResult = Result.exportFailed
            returnResult.supplementary = result.stderr
            return returnResult
        }
    }
}
