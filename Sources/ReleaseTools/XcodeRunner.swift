// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 17/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Runner
import Foundation
import CommandShell

extension Result {
    static let missingWorkspace = Result(201, "The workspace was not specified, and could not be inferred.")
    static let noDefaultScheme = Result(202, "No default scheme set.")
}


class XcodeRunner: Runner {
    init() {
        super.init(command: "xcodebuild")
    }
    
    func schemes(workspace: String) throws -> [String] {
        let result = try sync(arguments: ["-workspace", workspace, "-list", "-json"])
        if result.status == 0, let data = result.stdout.data(using: .utf8) {
            let decoder = JSONDecoder()
            let schemes = try decoder.decode(SchemesSpec.self, from: data)
            return schemes.workspace.schemes
        } else {
            print(result.stderr)
            return []
        }
    }
    
    var defaultWorkspace: String? {
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

    func setDefaultScheme(_ scheme: String, for workspace: String) {
        UserDefaults.standard.set(scheme, forKey: "defaultScheme.\(workspace)")
    }
    
    func scheme(for workspace: String, shell: Shell) -> String? {
        let scheme = shell.arguments.argument("scheme")
        return scheme.isEmpty ? defaultScheme(for: workspace) : scheme
    }
}
