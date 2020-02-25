// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 18/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import CommandShell

extension Result {
    static let commitFailed = Result(600, "Failed to commit the appcast feed and updates.")
    static let pushFailed = Result(601, "Failed to push the appcast feed and updates.")
}

class PublishCommand: RTCommand {
    override var description: Command.Description {
        return Description(
            name: "publish",
            help: "Commit and push any changes made to the website repo.",
            usage: ["[\(websiteOption)]"],
            options: ["\(websiteOption)": websiteOptionHelp]
        )
    }

    override func run(shell: Shell) throws -> Result {
        let gotRequirements = require([.archive])
        guard gotRequirements == .ok else {
            return gotRequirements
        }

        let git = GitRunner()
        git.cwd = websiteURL

        shell.log("Committing updates.")
        var result = try git.sync(arguments: ["add", updatesURL.path])
        if result.status != 0 {
            return Result.commitFailed.adding(runnerResult: result)
        }

        let message = "v\(archive.version), build \(archive.build)"
        result = try git.sync(arguments: ["commit", "-a", "-m", message])
        if result.status != 0 {
            return Result.commitFailed.adding(runnerResult: result)
        }
        
        shell.log("Pushing updates.")
        let pushResult = try git.sync(arguments: ["push"])
        if pushResult.status != 0 {
            return Result.pushFailed.adding(runnerResult: pushResult)
        }

        return .ok
    }
}
