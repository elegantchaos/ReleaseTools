// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 11/03/20.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import ArgumentParser

struct UnsetCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "unset",
        abstract: "Clear an option that was stored for use by other commands using \(CommandLine.name) set."
    )

    @Argument() var key: String
    @OptionGroup() var platform: PlatformOption
    @OptionGroup() var common: CommonOptions
    
    func run() throws {
        let parsed = try OptionParser(
            requires: [.workspace],
            options: common,
            command: Self.configuration,
            platform: platform,
            setDefaultPlatform: false
        )
        
        parsed.clearDefault(for: key)
    }
}
