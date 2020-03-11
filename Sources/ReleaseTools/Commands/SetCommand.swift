// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 11/03/20.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import ArgumentParser

struct SetCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "set",
        abstract: "Set an option for use by other commands."
    )

    @Argument() var key: String
    @Argument() var value: String
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
        
        parsed.setDefault(value, for: key)
    }
}

struct GetCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "get",
        abstract: "Get an option for use by other commands."
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
        
        if let value = parsed.getDefault(for: key) {
            parsed.log(value)
        } else {
            parsed.log("<not set>")
        }
    }
}
