// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 17/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Arguments
import Runner
import CommandShell

struct WorkspaceSpec: Decodable {
    let name: String
    let schemes: [String]
}

struct SchemesSpec: Decodable {
    let workspace: WorkspaceSpec
}

extension CommandLine {
    static var name: String {
        let url = URL(fileURLWithPath: arguments[0])
        return url.lastPathComponent
    }
}

extension Result {
    static let archiveFailed = Result(100, "Archiving failed.")
}

class ArchiveCommand: Command {
    static let archivePath = ".build/archive.xcarchive"
    
    override var name: String { return "archive" }

    override var usage: String { return "release archive [<scheme> [--set-default]]" }

    override var arguments: [String : String] { return [ "<scheme>": "name of the scheme to archive" ] }
    
    override var options: [String : String] { return [ "--set-default": "set the specified scheme as the default one to use" ] }

    override func run(shell: Shell) throws -> Result {
        
        let xcode = XcodeRunner()
        guard let workspace = xcode.defaultWorkspace else {
            return .badArguments
        }

        guard let scheme = xcode.scheme(for: workspace, shell: shell) else {
            var result = Result.noDefaultScheme
            result.supplementary = "Set using \(CommandLine.name) \(name) <scheme> --set-default."
            return result
        }

        if shell.arguments.flag("set-default") {
            xcode.setDefaultScheme(scheme, for: workspace)
        }
        
        shell.log("Archiving scheme \(scheme).")
        let result = try xcode.sync(arguments: ["-workspace", workspace, "-scheme", scheme, "archive", "-archivePath", ArchiveCommand.archivePath])
        if result.status == 0 {
            return .ok
        } else {
            var returnResult = Result.archiveFailed
            returnResult.supplementary = result.stderr
            return returnResult
        }
    }
}
