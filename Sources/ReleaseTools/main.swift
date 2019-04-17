// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 11/10/2018.
//  All code (c) 2018 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Runner
import Arguments



enum ReturnCode: Int32 {
    case ok = 0
    case unknownCommand = 1
    case badArguments = 2
    case archiveFailed = 3
    case runFailed = 4
    
    func returnStatus() -> Never {
        exit(rawValue)
    }
}

func buildDocumentation(for commands: [Command]) -> String {
    var usage = ""
    var arguments: [String:String] = [:]
    var options = [ "--help": "show help"]
    var returns: [ReturnCode:String] = [
        .ok: "If the arguments were ok and the command executed successfully.",
        .unknownCommand: "If the command was unknown.",
        .badArguments: "If there was an error parsing the arguments.",
        .runFailed: "If launching a sub-command failed."
    ]


    for command in commands {
        usage += "    \(command.usage)\n"
        arguments.merge(command.arguments, uniquingKeysWith: { (k1, k2) in return k1 })
        options.merge(command.options, uniquingKeysWith: { (k1, k2) in return k1 })
        returns.merge(command.returns, uniquingKeysWith: { (k1, k2) in return k1 })
    }

    var optionText = ""
    for option in options {
        optionText += "    \(option.key)     \(option.value)\n"
    }
    
    var argumentText = ""
    for argument in arguments {
        argumentText += "    \(argument.key)    \(argument.value)\n"
    }

    var returnText = ""
    for key in returns.keys.sorted(by: { return $0.rawValue < $1.rawValue }) {
        returnText += "    \(key.rawValue)    \(returns[key]!)\n"
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
    
    \(returnText)
    
    """
}

let commands = [ ArchiveCommand(), CompressCommand(), ExportCommand() ]
let documentation = buildDocumentation(for: commands)
let args = Arguments(documentation: documentation, version: "1.0")

for command in commands {
    if args.command(command.name) {
        do {
            try command.run(arguments: args).returnStatus()
        } catch {
            ReturnCode.runFailed.returnStatus()
        }
    }
}

ReturnCode.badArguments.returnStatus()

