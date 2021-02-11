// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 11/02/21.
//  All code (c) 2021 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Files
import Foundation
import Resources

enum ConfigsError: Error {
    case couldntCopyConfigs
    
    public var description: String {
        switch self {
            case .couldntCopyConfigs: return "Couldn't copy xcconfig files to \(ConfigsCommand.localFolder)."
        }
    }
}

struct ConfigsCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "configs",
        abstract: "Copy / update xcconfig files into the current project."
    )
    
    @OptionGroup() var options: CommonOptions

    static let localFolder = ThrowingManager.default.current.folder(".rt")

    func run() throws {
        do {
            let parsed = try OptionParser(
                options: options,
                command: Self.configuration
            )
            
            let destination = Self.localFolder
            parsed.log("Copying configs to \(destination.path).")
            try Resources.configsPath.merge(into: destination)
        } catch {
            throw ConfigsError.couldntCopyConfigs
        }
    }
}
