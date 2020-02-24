// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 17/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
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

struct ArchiveInfo {
    let build: String
    let version: String
    let name: String
    let shortName: String
    let lowername: String
    
    init(version: String, build: String, path: String) {
        self.build = build
        self.version = version
        let url = URL(fileURLWithPath: path)
        self.name = url.lastPathComponent
        self.shortName = url.deletingLastPathComponent().lastPathComponent
        self.lowername = shortName.lowercased()
    }
    
    var archiveName: String {
        return "\(lowername)-\(version)-\(build).zip"
    }
    
    var unversionedArchiveName: String {
        return "\(lowername).zip"
    }
    
}

class ArchiveCommand: RTCommand {
    
    override var description: Command.Description {
        return Description(
            name: "archive",
            help: "Make an archive for uploading, distribution, etc.",
            usage: ["[\(schemeOption) [\(setDefaultOption)]] [\(showOutputOption)]"],
            options: [
                schemeOption: schemeOptionHelp,
                setDefaultOption: setDefaultOptionHelp,
                showOutputOption : showOutputOptionHelp,
            ],
            returns: [.archiveFailed]
        )
    }
    
    override func run(shell: Shell) throws -> Result {
        
        guard let workspace = defaultWorkspace else {
            return .badArguments
        }

        guard let scheme = scheme(for: workspace, shell: shell) else {
            return Result.noDefaultScheme.adding(supplementary: "Set using \(CommandLine.name) \(description.name) <scheme> --set-default.")
        }

        if shell.arguments.flag("set-default") {
            setDefaultScheme(scheme, for: workspace)
        }
        
        shell.log("Archiving scheme \(scheme).")

        let xcode = XCodeBuildRunner(shell: shell)
        let result = try xcode.run(arguments: ["-workspace", workspace, "-scheme", scheme, "archive", "-archivePath", archiveURL.path])
        if result.status == 0 {
            return .ok
        } else {
            return Result.archiveFailed.adding(supplementary: result.stderr)
        }
    }
}
