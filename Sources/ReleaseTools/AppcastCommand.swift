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
}


class AppcastCommand: Command {
    
    override var description: Command.Description {
        return Description(
            name: "appcast",
            help: "Update the Sparkle appcast to include the zip created by the compress command.",
            usage: ["--to=<to>"],
            returns: [.buildAppcastGeneratorFailed, .appcastGeneratorFailed]
        )
    }
    
    override func run(shell: Shell) throws -> Result {
        let xcode = XcodeRunner()
        guard let workspace = xcode.defaultWorkspace else {
            return .badArguments
        }
        
        let keyChainPath = ("~/Library/Keychains/login.keychain" as NSString).expandingTildeInPath
        
        shell.log("Rebuilding appcast.")
        let build = "\(FileManager.default.currentDirectoryPath)/.build"
        let result = try xcode.sync(arguments: ["build", "-workspace", workspace, "-scheme", "generate_appcast", "BUILD_DIR=\(build)"], passthrough: true)
        if result.status != 0 {
            return Result.buildAppcastGeneratorFailed.adding(supplementary: result.stderr)
        }
        
        let workspaceName = URL(fileURLWithPath: workspace).deletingPathExtension().lastPathComponent
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
