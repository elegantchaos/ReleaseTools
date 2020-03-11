// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/02/20.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Runner
import Foundation

class DittoRunner: Runner {
    let parsed: StandardOptionParser
    init(parsed: StandardOptionParser) {
        self.parsed = parsed
        super.init(command: "ditto")
    }
    
    func run(arguments: [String]) throws -> Runner.Result {
        if parsed.showOutput {
            parsed.log("ditto " + arguments.joined(separator: " "))
        }
        
        return try sync(arguments: arguments, passthrough: parsed.showOutput)
    }
    
    func zip(_ url: URL, as zipURL: URL) throws -> Runner.Result {
        parsed.log("Compressing \(url.lastPathComponent) to \(zipURL.path).")
        return try run(arguments: ["-c", "-k", "--sequesterRsrc", "--keepParent", url.path, zipURL.path])
    }
}
