// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 17/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Arguments

open class Command {
    
    public init() {
    }
    
    open var name: String { return "" }

    open var usage: String { return "" }
    
    open var arguments: [String:String] { return [:] }
    
    open var options: [String:String] { return [:] }
    
    open var returns: [ReturnCode:String] { return [:] }
    
    open func run(arguments: Arguments) throws -> ReturnCode {
        print("Command \(name) unimplemented." )
        return .ok
    }

}
