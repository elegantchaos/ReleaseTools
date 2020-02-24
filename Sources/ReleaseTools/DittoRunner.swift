// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/02/20.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import CommandShell
import Runner
import Foundation

class DittoRunner: Runner {
    let shell: Shell
    
    init(shell: Shell) {
        self.shell = shell
        super.init(command: "/usr/bin/ditto")
    }
    
    func run(arguments: [String]) throws -> Runner.Result {
        let showBuild = shell.arguments.flag("show-build")
        if showBuild {
            shell.log("ditto " + arguments.joined(separator: " "))
        }
        
        return try sync(arguments: arguments, passthrough: showBuild)
    }
    
    func zip(_ url: URL, as zipURL: URL) throws -> Runner.Result {
        shell.log("Compressing \(url.lastPathComponent) to \(zipURL.path).")
        return try run(arguments: ["-c", "-k", "--sequesterRsrc", "--keepParent", url.path, zipURL.path])
    }
}
