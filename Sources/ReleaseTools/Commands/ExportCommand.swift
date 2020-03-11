// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 17/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Arguments
import ArgumentParser
import Foundation

enum ExportError: Error {
    case exportFailed(_ output: String)
    
    public var description: String {
        switch self {
            case .exportFailed(let output): return "Exporting failed.\n\(output)"
        }
    }
}

struct ExportCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Export an executable from the output of the archive command."
    )

    @OptionGroup() var options: StandardOptions

    func run() throws {
        let parsed = try StandardOptionParser([.package, .workspace, .scheme], options: options, name: "export")
        let xcode = XCodeBuildRunner(parsed: parsed)
        
        parsed.log("Exporting \(parsed.scheme).")
        try? FileManager.default.removeItem(at: parsed.exportURL)
        let result = try xcode.run(arguments: ["-exportArchive", "-archivePath", parsed.archiveURL.path, "-exportPath", parsed.exportURL.path, "-exportOptionsPlist", parsed.exportOptionsURL.path, "-allowProvisioningUpdates"])
        if result.status != 0 {
            throw ExportError.exportFailed(result.stderr)
        }
    }
}
