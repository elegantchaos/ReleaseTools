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
    static let keyGenerationFailed = Result(502, "Failed to generate appcast keys.")
    static let keyImportFailed = Result(503, "Failed to import appcast keys.")
    static let generatedKeys = Result(505, "The appcast private key was missing, so we've generated one.")
}


class AppcastCommand: RTCommand {
    
    override var description: Command.Description {
        return Description(
            name: "appcast",
            help: "Update the Sparkle appcast to include the zip created by the compress command.",
            usage: ["--to=<to> [--show-build]"],
            options: [
                "--show-build" : "show build command and output"
            ],
            returns: [.buildAppcastGeneratorFailed, .appcastGeneratorFailed, .keyGenerationFailed, .keyImportFailed, .generatedKeys]
        )
    }
    
    override func run(shell: Shell) throws -> Result {
        let xcode = XcodeRunner(shell: shell)
        guard let workspace = defaultWorkspace else {
            return .badArguments
        }
        
        let keyChainPath = ("~/Library/Keychains/login.keychain" as NSString).expandingTildeInPath
        
        shell.log("Rebuilding appcast.")
        let fm = FileManager.default
        let rootURL = URL(fileURLWithPath: fm.currentDirectoryPath)
        let buildURL = rootURL.appendingPathComponent(".build")
        let result = try xcode.run(arguments: ["build", "-workspace", workspace, "-scheme", "generate_appcast", "BUILD_DIR=\(buildURL.path)"])
        if result.status != 0 {
            return Result.buildAppcastGeneratorFailed.adding(supplementary: result.stderr)
        }
        
        let workspaceName = URL(fileURLWithPath: workspace).deletingPathExtension().lastPathComponent
        let keyName = "\(workspaceName) Sparkle Key"
        let appcastPath = try shell.arguments.expectedOption("to")
        
        let generator = Runner(for: URL(fileURLWithPath: ".build/Release/generate_appcast"))
        let genResult = try generator.sync(arguments: ["-n", keyName, "-k", keyChainPath, appcastPath])
        if genResult.status != 0 {
            if !genResult.stdout.contains("Unable to load DSA private key") {
                return Result.appcastGeneratorFailed.adding(runnerResult: genResult)
            }
            
            shell.log("Could not find Sparkle key - generating one.")

            guard let scheme = scheme(for: workspace, shell: shell) else {
                return Result.noDefaultScheme.adding(supplementary: "Set using the archive command.")
            }

            let keygen = Runner(for: URL(fileURLWithPath: "Dependencies/Sparkle/bin/generate_keys"))
            let keygenResult = try keygen.sync(arguments: [])
            if keygenResult.status != 0 {
                return Result.keyGenerationFailed.adding(runnerResult: keygenResult)
            }

            shell.log("Importing Key.")

            let security = Runner(for: URL(fileURLWithPath: "/usr/bin/security"))
            let importResult = try security.sync(arguments: ["import", "dsa_priv.pem", "-a", "labl", "\(scheme) Sparkle Key"])
            if importResult.status != 0 {
                return Result.keyImportFailed.adding(runnerResult: importResult)
            }
            
            shell.log("Moving Public Key.")

            try? fm.moveItem(at: rootURL.appendingPathComponent("dsa_pub.pem"), to: rootURL.appendingPathComponent("Sources").appendingPathComponent(scheme).appendingPathComponent("Resources").appendingPathComponent("dsa_pub.pem"))

            shell.log("Deleting Private Key.")

            try? fm.removeItem(at: rootURL.appendingPathComponent("dsa_priv.pem"))
            
            return Result.generatedKeys.adding(runnerResult: genResult).adding(supplementary: "Open the keychain, rename the key `Imported Private Key` as `\(keyName)`, then try running this command again.")
        }
        
        try? fm.removeItem(at: URL(fileURLWithPath: appcastPath).appendingPathComponent(".tmp"))

        return .ok
    }
}
