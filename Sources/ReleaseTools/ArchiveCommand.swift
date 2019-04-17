// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 17/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Arguments
import Runner

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

class ArchiveCommand: Command {
    override var name: String { return "archive" }

    override var usage: String { return "release archive [<scheme> [--set-default]]" }

    override var arguments: [String : String] { return [ "<scheme>": "name of the scheme to archive" ] }
    
    override var options: [String : String] { return [ "--set-default": "set the specified scheme as the default one to use" ] }

    
    func defaultWorkspace() -> String? {
        let url = URL(fileURLWithPath: ".")
        if let contents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [], options: [.skipsPackageDescendants, .skipsSubdirectoryDescendants, .skipsHiddenFiles]) {
            for item in contents {
                if item.pathExtension == "xcworkspace" {
                    return item.lastPathComponent
                }
            }
        }
        return nil
    }
    
    func defaultScheme(for workspace: String) -> String? {
        return UserDefaults.standard.string(forKey: "defaultScheme.\(workspace)")
    }
    
    func schemes(xcode: Runner, workspace: String) throws -> [String] {
        let result = try xcode.sync(arguments: ["-workspace", workspace, "-list", "-json"])
        if result.status == 0, let data = result.stdout.data(using: .utf8) {
            let decoder = JSONDecoder()
            let schemes = try decoder.decode(SchemesSpec.self, from: data)
            return schemes.workspace.schemes
        } else {
            print(result.stderr)
            return []
        }
    }
    
    override func run(arguments: Arguments) throws -> ReturnCode {
        
        let xcode = Runner(for: URL(fileURLWithPath: "/usr/bin/xcodebuild"))
        guard let workspace = defaultWorkspace() else {
            return .badArguments
        }

        var scheme = arguments.argument("scheme")
        if scheme.isEmpty, let defaultScheme = defaultScheme(for: workspace) {
            scheme = defaultScheme
        }
        guard !scheme.isEmpty else {
            print("No default scheme set for archiving.")
            print("Set using \(CommandLine.name) archive <scheme> --set-default")
            return .badArguments
        }

        if arguments.flag("set-default") {
            UserDefaults.standard.set(scheme, forKey: "defaultScheme.\(workspace)")
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
