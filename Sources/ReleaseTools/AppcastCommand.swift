// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 18/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import CommandShell
import Runner

extension Result {
    static let buildAppcastGeneratorFailed = Result(500, "Failed to build the generate_appcast tool.")
    static let appcastGeneratorFailed = Result(501, "Failed to generate the appcast.")
    static let couldntGetKeychainPath = Result(502, "Failed to get the keychain path.")
}


class AppcastCommand: Command {
    
    override var name: String { return "appcast" }
    
    override var usage: [String] { return ["appcast --to=<to>"] }

    override var returns: [Result] { return [.buildAppcastGeneratorFailed, .appcastGeneratorFailed, .couldntGetKeychainPath] }
    
    override func run(shell: Shell) throws -> Result {
        let xcode = XcodeRunner()
        guard let workspace = xcode.defaultWorkspace else {
            return .badArguments
        }
        
        guard let keyChainPath = NSURL(fileURLWithPath: "~/Library/Keychains/login.keychain").standardizingPath?.path else {
            return .couldntGetKeychainPath
        }
        
        shell.log("Rebuilding appcast.")
        let result = try xcode.sync(arguments: ["build", "-workspace", workspace, "-scheme", "generate_appcast", "BUILD_DIR=.build"])
        if result.status != 0 {
            return Result.buildAppcastGeneratorFailed.adding(supplementary: result.stderr)
        }
        
        let workspaceName = URL(fileURLWithPath: workspace).deletingPathExtension().path
        let keyName = "\(workspaceName) Sparkle Key"
        let appcastPath = try shell.arguments.expectedOption("to")
        
        let generator = Runner(for: URL(fileURLWithPath: ".build/Release/generate_appcast"))
        let genResult = try generator.sync(arguments: ["-n", keyName, "-k", keyChainPath, appcastPath])
        if genResult.status != 0 {
            return Result.appcastGeneratorFailed.adding(runnerResult: genResult)
        }
        
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: appcastPath).appendingPathComponent(".tmp"))

        return .ok
    }
}
