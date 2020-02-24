// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 17/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Runner
import Foundation
import CommandShell

class XCodeBuildRunner: Runner {
    let shell: Shell
    
    init(shell: Shell) {
        self.shell = shell
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
    
    func run(arguments: [String]) throws -> Runner.Result {
        let showBuild = shell.arguments.flag("show-output")
        if showBuild {
            shell.log("xcodebuild " + arguments.joined(separator: " "))
        }
        
        return try sync(arguments: arguments, passthrough: showBuild)
    }
}
