// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 19/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import CommandShell


extension Result {
    static let gettingBuildFailed = Result(700, "Failed to get the build number from git.")
    static let gettingCommitFailed = Result(701, "Failed to get the commit from git.")
    static let writingConfigFailed = Result(702, "Failed to write the config file.")
    static let updatingIndexFailed = Result(703, "Failed to tell git to ignore the config file.")
}

class UpdateBuildCommand: Command {
    
    override var name: String { return "update-build" }
    
    override var usage: [String] { return ["[--repo=<repo>]"] }

    override var options: [String : String] { return ["--repo=<repo>": "The repository to operate on."] }

    override func run(shell: Shell) throws -> Result {
        let git = GitRunner()
        if let repo = shell.arguments.option("repo") {
            git.cwd = URL(fileURLWithPath: repo)
            chdir(repo)
        }

        var result = try git.sync(arguments: ["rev-list", "--count", "HEAD"])
        if result.status != 0 {
            return Result.gettingBuildFailed.adding(runnerResult: result)
        }
        
        let build = result.stdout.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        result = try git.sync(arguments: ["rev-list", "--max-count", "1", "HEAD"])
        if result.status != 0 {
            return Result.gettingCommitFailed.adding(runnerResult: result)
        }
        
        let commit = result.stdout.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let new = "BUILD_NUMBER = \(build)\nBUILD_COMMIT = \(commit)"
        let configURL = URL(fileURLWithPath: "Configs/BuildNumber.xcconfig")
        if let existing = try? String(contentsOf: configURL), existing == new {
            shell.log("Build number is \(build).")
        } else {
            shell.log("Updating build number to \(build).")
            do {
              try new.write(to: configURL, atomically: true, encoding: .utf8)
            } catch {
                return .writingConfigFailed
            }
            
            result = try git.sync(arguments: ["update-index", "--assume-unchanged", "Configs/BuildNumber.xcconfig"])
            if result.status != 0 {
                return Result.updatingIndexFailed.adding(runnerResult: result)
            }

        }
        
        return .ok
    }
  
}
