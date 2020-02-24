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
    
    override var description: Command.Description {
        return Description(
            name: "update-build",
            help: "Update BuildNumber.xcconfig to contain the latest build number.",
            usage: ["[--config=<config>]"],
            options: ["--config=<config>": "The configuration file to update."],
            returns: [.gettingBuildFailed, .gettingCommitFailed, .writingConfigFailed, .updatingIndexFailed]
        )
    }

    override func run(shell: Shell) throws -> Result {
        let git = GitRunner()

        let configURL: URL
        if let config = shell.arguments.option("config") {
            configURL = URL(fileURLWithPath: config)
        } else if let sourceRoot = ProcessInfo.processInfo.environment["SOURCE_ROOT"] {
            configURL = URL(fileURLWithPath: sourceRoot).appendingPathComponent("Configs").appendingPathComponent("BuildNumber.xcconfig")
        } else {
            configURL = URL(fileURLWithPath: "Configs/BuildNumber.xcconfig")
        }
        
        let configRoot = configURL.deletingLastPathComponent()
        git.cwd = configRoot
        chdir(configRoot.path)

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

        if let existing = try? String(contentsOf: configURL), existing == new {
            shell.log("Build number is \(build).")
        } else {
            shell.log("Updating build number to \(build).")
            do {
              try new.write(to: configURL, atomically: true, encoding: .utf8)
            } catch {
                return .writingConfigFailed
            }
            
            result = try git.sync(arguments: ["update-index", "--assume-unchanged", configURL.path])
            if result.status != 0 {
                return Result.updatingIndexFailed.adding(runnerResult: result)
            }

        }
        
        return .ok
    }
  
}
