// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 18/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import CommandShell
import Runner
import ArgumentParser

enum AppcastError: Error, CustomStringConvertible {
    case buildAppcastGeneratorFailed(_ output: String)
    case appcastGeneratorFailed(_ result: Runner.Result)
    case keyGenerationFailed(_ result: Runner.Result)
    case keyImportFailed(_ result: Runner.Result)
    case generatedKeys(_ name: String)

    public var description: String {
        switch self {
            case .buildAppcastGeneratorFailed(let output): return "Failed to build the generate_appcast tool.\n\(output)"
            case .appcastGeneratorFailed(let result): return "Failed to generate the appcast.\n\(result)"
            case .keyGenerationFailed(let result): return "Failed to generate appcast keys.\n\(result)"
            case .keyImportFailed(let result): return "Failed to import appcast keys.\n\(result)"
            case .generatedKeys(let name): return """
                The appcast private key was missing, so we've generated one.
                Open the keychain, rename the key `Imported Private Key` as `\(name)`, then try running this command again.
                """
        }
    }
}


struct AppcastCommand: ParsableCommand {
    init() {
    }
    
    static var configuration = CommandConfiguration(
        abstract: "Update the Sparkle appcast to include the zip created by the compress command."
    )

    @OptionGroup
    var options: StandardOptions
    
//    @Option(help: "The local path to the repository containing the website, where the appcast and zip archives live. Defaults to `Dependencies/Website`.")
//    var website: String?
//
//    @Option(help: "The local path to the updates folder inside the website repository. Defaults to `Dependencies/Website/updates`.")
//    var updates: String?

    func run() throws {
        let parsed = try StandardOptionParser([.workspace, .scheme], options: options, name: "Appcast")

        let xcode = XCodeBuildRunner(shell: shell)
        
        let keyChainPath = ("~/Library/Keychains/login.keychain" as NSString).expandingTildeInPath
        
        shell.log("Rebuilding appcast.")
        let fm = FileManager.default
        let rootURL = URL(fileURLWithPath: fm.currentDirectoryPath)
        let buildURL = rootURL.appendingPathComponent(".build")
        let result = try xcode.run(arguments: ["build", "-workspace", parsed.workspace, "-scheme", "generate_appcast", "BUILD_DIR=\(buildURL.path)"])
        if result.status != 0 {
            throw AppcastError.buildAppcastGeneratorFailed(result.stderr)
        }
        
        let workspaceName = URL(fileURLWithPath: parsed.workspace).deletingPathExtension().lastPathComponent
        let keyName = "\(workspaceName) Sparkle Key"
        
        let generator = Runner(for: URL(fileURLWithPath: ".build/Release/generate_appcast"))
        let genResult = try generator.sync(arguments: ["-n", keyName, "-k", keyChainPath, parsed.updatesURL.path])
        if genResult.status != 0 {
            if !genResult.stdout.contains("Unable to load DSA private key") {
                throw AppcastError.appcastGeneratorFailed(genResult)
            }
            
            shell.log("Could not find Sparkle key - generating one.")

            let keygen = Runner(for: URL(fileURLWithPath: "Dependencies/Sparkle/bin/generate_keys"))
            let keygenResult = try keygen.sync(arguments: [])
            if keygenResult.status != 0 {
                throw AppcastError.keyGenerationFailed(keygenResult)
            }

            shell.log("Importing Key.")

            let security = Runner(for: URL(fileURLWithPath: "/usr/bin/security"))
            let importResult = try security.sync(arguments: ["import", "dsa_priv.pem", "-a", "labl", "\(parsed.scheme) Sparkle Key"])
            if importResult.status != 0 {
                throw AppcastError.keyImportFailed(importResult)
            }
            
            shell.log("Moving Public Key.")

            try? fm.moveItem(at: rootURL.appendingPathComponent("dsa_pub.pem"), to: rootURL.appendingPathComponent("Sources").appendingPathComponent(parsed.scheme).appendingPathComponent("Resources").appendingPathComponent("dsa_pub.pem"))

            shell.log("Deleting Private Key.")

            try? fm.removeItem(at: rootURL.appendingPathComponent("dsa_priv.pem"))
            
            throw AppcastError.generatedKeys(keyName)
        }
        
        try? fm.removeItem(at: URL(fileURLWithPath: parsed.updatesURL.path).appendingPathComponent(".tmp"))
    }
}
