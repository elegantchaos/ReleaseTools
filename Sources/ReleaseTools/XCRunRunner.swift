// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/02/20.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import CommandShell
import Runner

class XCRunRunner: Runner {
    let shell: Shell
    
    init(shell: Shell) {
        self.shell = shell
        super.init(command: "xcrun")
    }
    
    func run(arguments: [String]) throws -> Runner.Result {
        let showBuild = shell.arguments.flag("show-build")
        if showBuild {
            shell.log("xcrun " + arguments.joined(separator: " "))
        }
        
        return try sync(arguments: arguments, passthrough: showBuild)
    }
}
