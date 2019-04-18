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
        if result.code != 0 {
            print("Error: \(result.description)")
            if !result.supplementary.isEmpty {
                print(result.supplementary)
            }
        } else {
            print("Done.")
        }

        print("")
        Foundation.exit(result.code)
    }
    
    public func run() {
        for command in commands {
            if arguments.command(command.name) {
                do {
                    let result = try command.run(shell: self)
                    exit(result: result)
                    
                } catch {
                    exit(result: Result.runFailed.adding(supplementary: String(describing: error)))
                }
            }
        }
        
        exit(result: .badArguments)
    }

    public func log(_ message: String) {
        print(message)
    }
    
    class func buildDocumentation(for commands: [Command]) -> String {
        var usages: [String] = []
        var arguments: [String:String] = [:]
        var options = [ "--help": "Show this help."]
        var results: [Result] = [ .ok, .unknownCommand, .badArguments, .runFailed ]
        
        for command in commands {
            usages.append(contentsOf: command.usage)
            arguments.merge(command.arguments, uniquingKeysWith: { (k1, k2) in return k1 })
            options.merge(command.options, uniquingKeysWith: { (k1, k2) in return k1 })
            results.append(contentsOf: command.returns)
        }
        
        let name = CommandLine.name
        var usageText = ""
        for usage in usages {
            usageText += "    \(name) \(usage)\n"
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
        var codesUsed: [Int32:String] = [:]
        for key in results.sorted(by: { return $0.code < $1.code }) {
            if let duplicate = codesUsed[key.code] {
                print("Warning: duplicate code \(key.code) for \(key.description) and \(duplicate)")
            }
            codesUsed[key.code] = key.description
            resultText += "    \(key.code)    \(key.description)\n"
        }
        
        return """
        Various release utilities.
        
        Usage:
        \(usageText)
        
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
