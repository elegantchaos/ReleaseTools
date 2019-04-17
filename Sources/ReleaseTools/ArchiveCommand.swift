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
    override var name: String { return "archive" }

    override var usage: String { return "release archive [<scheme> [--set-default]]" }

    override var arguments: [String : String] { return [ "<scheme>": "name of the scheme to archive" ] }
    
    override var options: [String : String] { return [ "--set-default": "set the specified scheme as the default one to use" ] }

    override func run(shell: Shell) throws -> Result {
        
        let xcode = XcodeRunner()
        guard let workspace = xcode.defaultWorkspace else {
            return .badArguments
        }

        var scheme = shell.arguments.argument("scheme")
        if scheme.isEmpty, let defaultScheme = xcode.defaultScheme(for: workspace) {
            scheme = defaultScheme
        }
        guard !scheme.isEmpty else {
            print("No default scheme set for archiving.")
            print("Set using \(CommandLine.name) archive <scheme> --set-default")
            return .badArguments
        }

        if shell.arguments.flag("set-default") {
            xcode.setDefaultScheme(scheme, for: workspace)
        }
        
        print("Archiving scheme \(scheme).")
        let result = try xcode.sync(arguments: ["-workspace", workspace, "-scheme", scheme, "archive", "-archivePath", ".build/archive"])
        if result.status == 0 {
            return .ok
        } else {
            print(result.stderr)
            return .archiveFailed
        }
    }
}
