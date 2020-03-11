// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 17/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import ArgumentParser
import Runner

enum CompressError: Error {
    case compressFailed(_ output: String)
    
    public var description: String {
        switch self {
            case .compressFailed(let output): return "Compressing failed.\n\(output)"
        }
    }
}

struct CompressCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "compress",
        abstract: "Compress the output of the export command for distribution."
    )

    @OptionGroup() var scheme: SchemeOption
    @OptionGroup() var setDefault: SetDefaultArgument
    @OptionGroup() var options: StandardOptions

    func run() throws {
        let parsed = try StandardOptionParser(
            options: options,
            command: Self.configuration,
            scheme: scheme,
            setDefaultArgument: setDefault
        )

        let stapledAppURL = parsed.stapledURL.appendingPathComponent(parsed.archive.name)
        let ditto = DittoRunner(parsed: parsed)
        let destination = options.updatesURL.appendingPathComponent(parsed.archive.versionedZipName)
        
        let result = try ditto.zip(stapledAppURL, as: destination)
        if result.status != 0 {
            throw CompressError.compressFailed(result.stderr)
        }
        
        parsed.log("Saving copy of archive to \(options.websiteURL.path) as \(parsed.archive.unversionedZipName).")
        let latestZip = options.websiteURL.appendingPathComponent(parsed.archive.unversionedZipName)
        try? FileManager.default.removeItem(at: latestZip)
        try FileManager.default.copyItem(at: destination, to: latestZip)
    }
}
