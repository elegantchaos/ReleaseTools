// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 19/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import ArgumentParser
import Runner

enum UpdateBuildError: Error {
    case gettingBuildFailed(_ result: Runner.Result)
    case gettingCommitFailed(_ result: Runner.Result)
    case writingConfigFailed
    case updatingIndexFailed(_ result: Runner.Result)

    public var description: String {
        switch self {
            case .gettingBuildFailed(let result): return "Failed to get the build number from git.\n\(result)"
            case .gettingCommitFailed(let result): return "Failed to get the commit from git.\n\(result)"
            case .writingConfigFailed: return "Failed to write the config file."
            case .updatingIndexFailed(let result): return "Failed to tell git to ignore the config file.\n\(result)"
        }
    }
}

struct UpdateBuildCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "update",
        abstract: "Update BuildNumber.xcconfig to contain the latest build number."
    )

    @Option(help: "The configuration file to update.") var config: String?
    @OptionGroup() var options: CommonOptions

    func run() throws {
        let parsed = try StandardOptionParser([], options: options, command: Self.configuration)
        let git = GitRunner()

        let configURL: URL
        if let config = config {
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
            throw UpdateBuildError.gettingBuildFailed(result)
        }
        
        let build = result.stdout.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        result = try git.sync(arguments: ["rev-list", "--max-count", "1", "HEAD"])
        if result.status != 0 {
            throw UpdateBuildError.gettingCommitFailed(result)
        }
        
        let commit = result.stdout.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let new = "BUILD_NUMBER = \(build)\nBUILD_COMMIT = \(commit)"

        if let existing = try? String(contentsOf: configURL), existing == new {
            parsed.log("Build number is \(build).")
        } else {
            parsed.log("Updating build number to \(build).")
            do {
              try new.write(to: configURL, atomically: true, encoding: .utf8)
            } catch {
                throw UpdateBuildError.writingConfigFailed
            }
            
            result = try git.sync(arguments: ["update-index", "--assume-unchanged", configURL.path])
            if result.status != 0 {
                throw UpdateBuildError.updatingIndexFailed(result)
            }

        }
    }
  
}
