// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 17/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Arguments

class Command {
    var name: String { return "" }

    var usage: String { return "" }
    
    var arguments: [String:String] { return [:] }
    
    var options: [String:String] { return [:] }
    
    var returns: [ReturnCode:String] { return [:] }
    
    func run(arguments: Arguments) throws -> ReturnCode {
        print("Command \(name) unimplemented." )
        return .ok
    }

}
