// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 17/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Arguments
import Foundation

public class Shell {
    let commands: [Command]
    public let arguments: Arguments
    
    public init(commands: [Command]) {
        self.commands = commands
        let documentation = Shell.buildDocumentation(for: commands)
        self.arguments = Arguments(documentation: documentation, version: "1.0")
    }
    
    public func exit(result: Result) -> Never {
        Foundation.exit(result.code)
    }
    
    public func run() {
        for command in commands {
            if arguments.command(command.name) {
                do {
                    let result = try command.run(shell: self)
                    exit(result: result)
                    
                } catch {
                    exit(result: .runFailed)
                }
            }
        }
        
        exit(result: .badArguments)
    }

    class func buildDocumentation(for commands: [Command]) -> String {
        var usage = ""
        var arguments: [String:String] = [:]
        var options = [ "--help": "show help"]
        var results: [Result] = [ .ok, .unknownCommand, .badArguments, .runFailed ]
        
        for command in commands {
            usage += "    \(command.usage)\n"
            arguments.merge(command.arguments, uniquingKeysWith: { (k1, k2) in return k1 })
            options.merge(command.options, uniquingKeysWith: { (k1, k2) in return k1 })
            results.append(contentsOf: command.returns)
        }
        
        var optionText = ""
        for option in options {
            optionText += "    \(option.key)     \(option.value)\n"
        }
        
        var argumentText = ""
        for argument in arguments {
            argumentText += "    \(argument.key)    \(argument.value)\n"
        }
        
        var resultText = ""
        for key in results.sorted(by: { return $0.code < $1.code }) {
            resultText += "    \(key.code)    \(key.description)\n"
        }
        
        return """
        Various release utilities.
        
        Usage:
        \(usage)
        
        Arguments:
        \(argumentText)
        
        Options:
        \(optionText)
        
        Exit Status:
        
        The command exits with one of the following values:
        
        \(resultText)
        
        """
    }
    
}
