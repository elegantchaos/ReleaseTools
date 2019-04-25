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

class PublishCommand: Command {
    
    override var name: String { return "publish" }
    
    override var usage: [String] { return ["publish --repo=<repo>"] }
    
    override var options: [String : String] { return ["--repo=<repo>": "The repository containing the appcast and updates."] }
    
    override func run(shell: Shell) throws -> Result {
        let git = GitRunner()
        let appcastRepo = try shell.arguments.expectedOption("repo")
        git.cwd = URL(fileURLWithPath: appcastRepo)

        guard let archive = XcodeArchive(url: URL(fileURLWithPath: ArchiveCommand.archivePath)) else {
            return .infoUnreadable
        }
        
        shell.log("Committing updates.")
        let message = "v\(archive.version), build \(archive.build)"
        let result = try git.sync(arguments: ["commit", "-a", "-m", message])
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
