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
        abstract: "Commit and push any changes made to the website repo."
    )

    @OptionGroup var options: StandardOptions

    func run() throws {
        let parsed = try StandardOptionParser([.archive], options: options, name: "publish")

        let git = GitRunner()
        git.cwd = parsed.websiteURL

        shell.log("Committing updates.")
        var result = try git.sync(arguments: ["add", parsed.updatesURL.path])
        if result.status != 0 {
            throw PublishError.commitFailed(result)
        }

        let message = "v\(parsed.archive.version), build \(parsed.archive.build)"
        result = try git.sync(arguments: ["commit", "-a", "-m", message])
        if result.status != 0 {
            throw PublishError.commitFailed(result)
        }
        
        shell.log("Pushing updates.")
        let pushResult = try git.sync(arguments: ["push"])
        if pushResult.status != 0 {
            throw PublishError.pushFailed(result)
        }
    }
}
