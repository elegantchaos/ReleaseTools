// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/02/20.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import ArgumentParser
import Runner


enum NotarizeError: Error {
    case compressingFailed(_ result: Runner.Result)
    case notarizingFailed(_ result: Runner.Result)
    case savingNotarizationReceiptFailed(_ error: Error)

    public var description: String {
        switch self {
            case .compressingFailed(let result): return "Compressing failed.\n\(result)"
            case .notarizingFailed(let result): return "Notarizing failed.\n\(result)"
            case .savingNotarizationReceiptFailed(let error): return "Saving notarization receipt failed.\n\(error)"
        }
    }
}

extension Result {
}

struct NotarizeCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Notarize the compressed archive."
    )

    @OptionGroup var options: StandardOptions
    
    func run() throws {
        let parsed = try StandardOptionParser([.workspace, .scheme], options: options, name: "notarize")

        shell.log("Creating archive for notarization.")
        let ditto = DittoRunner(shell: shell)
        
        let zipResult = try ditto.zip(parsed.exportedAppURL, as: parsed.exportedZipURL)
        if zipResult.status != 0 {
            throw NotarizeError.compressingFailed(zipResult)
        }

        shell.log("Uploading archive to notarization service.")
        let xcrun = XCRunRunner(shell: shell)
        let result = try xcrun.run(arguments: ["altool", "--notarize-app", "--primary-bundle-id", parsed.archive.identifier, "--username", parsed.user, "--password", "@keychain:AC_PASSWORD", "--file", parsed.exportedZipURL.path, "--output-format", "xml"])
        if result.status != 0 {
            throw NotarizeError.notarizingFailed(result)
        }

        shell.log("Requested notarization.")
        do {
            try result.stdout.write(to: parsed.notarizingReceiptURL, atomically: true, encoding: .utf8)
        } catch {
            throw NotarizeError.savingNotarizationReceiptFailed(error)
        }
    }
}
