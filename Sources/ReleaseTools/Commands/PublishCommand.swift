// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 18/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import ArgumentParser
import Runner

enum PublishError: Error {
    case commitFailed(_ result: Runner.Result)
    case pushFailed(_ result: Runner.Result)
    
    public var description: String {
        switch self {
            case . commitFailed(let result): return "Failed to commit the appcast feed and updates.\n\(result)"
            case .pushFailed(let result): return "Failed to push the appcast feed and updates.\n\(result)"
        }
    }
}

struct PublishCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "publish",
        abstract: "Commit and push any changes made to the website repo."
    )

    @OptionGroup() var website: WebsiteOption
    @OptionGroup() var updates: UpdatesOption
    @OptionGroup() var options: CommonOptions

    func run() throws {
        let parsed = try OptionParser(
            requires: [.archive],
            options: options,
            command: Self.configuration
        )

        let git = GitRunner()
        git.cwd = website.websiteURL

        parsed.log("Committing updates.")
        var result = try git.sync(arguments: ["add", updates.path])
        if result.status != 0 {
            throw PublishError.commitFailed(result)
        }

        let message = "v\(parsed.archive.version), build \(parsed.archive.build)"
        result = try git.sync(arguments: ["commit", "-a", "-m", message])
        if result.status != 0 {
            throw PublishError.commitFailed(result)
        }
        
        parsed.log("Pushing updates.")
        let pushResult = try git.sync(arguments: ["push"])
        if pushResult.status != 0 {
            throw PublishError.pushFailed(result)
        }
    }
}
