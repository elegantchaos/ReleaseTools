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

extension Result {
    static let archiveFailed = Result(100, "Archiving failed.")
}

class ArchiveCommand: Command {
    static let archivePath = ".build/archive.xcarchive"
    
    override var name: String { return "archive" }

    override var usage: [String] { return ["archive [<scheme> [--set-default]]"] }

    override var arguments: [String : String] { return [ "<scheme>": "name of the scheme to archive" ] }
    
    override var options: [String : String] { return [ "--set-default": "set the specified scheme as the default one to use" ] }

    override var returns: [Result] { return [.archiveFailed] }
    
    override func run(shell: Shell) throws -> Result {
        
        let xcode = XcodeRunner()
        guard let workspace = xcode.defaultWorkspace else {
            return .badArguments
        }

        guard let scheme = xcode.scheme(for: workspace, shell: shell) else {
            return Result.noDefaultScheme.adding(supplementary: "Set using \(CommandLine.name) \(name) <scheme> --set-default.")
        }

        if shell.arguments.flag("set-default") {
            xcode.setDefaultScheme(scheme, for: workspace)
        }
        
        shell.log("Archiving scheme \(scheme).")
        let result = try xcode.sync(arguments: ["-workspace", workspace, "-scheme", scheme, "archive", "-archivePath", ArchiveCommand.archivePath])
        if result.status == 0 {
            return .ok
        } else {
            return Result.archiveFailed.adding(supplementary: result.stderr)
        }
    }
}
