// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 11/02/21.
//  All code (c) 2021 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Files
import Foundation
import Resources

struct BootstrapCommand: ParsableCommand {
    enum Error: Swift.Error {
        case couldntCopyConfigs(error: Swift.Error)
        
        public var description: String {
            switch self {
                case let .couldntCopyConfigs(error): return "Couldn't copy files \(error)."
            }
        }
    }


    static var configuration = CommandConfiguration(
        commandName: "bootstrap",
        abstract: "Copy xcconfig and script files into the current project."
    )
    
    @OptionGroup() var options: CommonOptions

    static let localConfigFolder = ThrowingManager.default.current.folder(".rt")
    static let localScriptsFolder = ThrowingManager.default.current.folder("Extras/Scripts")

    func run() throws {
        do {
            let parsed = try OptionParser(
                options: options,
                command: Self.configuration
            )
            
//            parsed.log("Copying .xcconfig files to \(Self.localConfigFolder).")
//            try Resources.configsPath.merge(into: Self.localConfigFolder)

            parsed.log("Copying scripts to \(Self.localScriptsFolder).")
            try Resources.scriptsPath.merge(into: Self.localScriptsFolder)

        } catch {
            throw Error.couldntCopyConfigs(error: error)
        }
    }
}
