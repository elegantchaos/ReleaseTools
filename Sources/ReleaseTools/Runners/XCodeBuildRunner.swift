// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 17/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Runner
import Foundation

class XCodeBuildRunner: Runner {
    let parsed: StandardOptionParser
    
    init(parsed: StandardOptionParser) {
        self.parsed = parsed
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
        if parsed.showOutput {
            parsed.log("xcodebuild " + arguments.joined(separator: " "))
        }
        
        return try sync(arguments: arguments, passthrough: parsed.showOutput)
    }
}
