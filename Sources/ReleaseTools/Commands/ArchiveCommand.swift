// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 17/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import ArgumentParser

struct WorkspaceSpec: Decodable {
    let name: String
    let schemes: [String]
}

struct SchemesSpec: Decodable {
    let workspace: WorkspaceSpec
}

enum ArchiveError: Error {
    case archiveFailed(_ output: String)
    
    public var description: String {
        switch self {
            case .archiveFailed(let output): return "Archiving failed.\n\(output)"
        }
    }
}

struct ArchiveCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "archive",
        abstract: "Make an archive for uploading, distribution, etc."
    )

    @OptionGroup() var scheme: SchemeOption
    @OptionGroup() var setDefault: SetDefaultOption
    @OptionGroup() var platform: PlatformOption
    @OptionGroup() var options: StandardOptions

    func run() throws {
        let parsed = try StandardOptionParser(
            options: options,
            command: Self.configuration,
            scheme: scheme,
            platform: platform,
            setDefaultArgument: setDefault)
        
        parsed.log("Archiving scheme \(parsed.scheme).")

        let xcode = XCodeBuildRunner(parsed: parsed)
        var args = ["-workspace", parsed.workspace, "-scheme", parsed.scheme, "archive", "-archivePath", parsed.archiveURL.path]
        switch parsed.platform {
            case "iOS":
                args.append(contentsOf: ["-sdk", "iphoneos"])
            case "tvOS":
                args.append(contentsOf: ["-sdk", "appletvos"])
            case "watchOS":
                args.append(contentsOf: ["-sdk", "watchos"])
            default:
                break
        }

        let result = try xcode.run(arguments: args)
        if result.status != 0 {
            throw ArchiveError.archiveFailed(result.stderr)
        }
    }
}
