// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/02/20.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Runner

class XCRunRunner: Runner {
    let parsed: OptionParser
    
    init(parsed: OptionParser) {
        self.parsed = parsed
        super.init(command: "xcrun")
    }
    
    func run(arguments: [String]) throws -> Runner.Result {
        if parsed.showOutput {
            parsed.log("xcrun " + arguments.joined(separator: " "))
        }
        
        return try sync(arguments: arguments, passthrough: parsed.showOutput)
    }
}
