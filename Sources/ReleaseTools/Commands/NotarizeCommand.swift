// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/02/20.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import CommandShell
import Runner

extension Result {
    static let notarizingFailed = Result(600, "Notarizing failed.")
    static let savingNotarizationReceiptFailed = Result(601, "Saving notarization receipt failed.")
}

class NotarizeCommand: RTCommand {
    override var description: Command.Description {
        return Description(
            name: "notarize",
            help: "Notarize the compressed archive.",
            usage: ["[\(userOption) [\(setDefaultOption)]]"],
            options: [
                userOption: userOptionHelp,
                setDefaultOption: setDefaultOptionHelp
            ],
            returns: [.notarizingFailed, .savingNotarizationReceiptFailed]
        )
    }
    
    override func run(shell: Shell) throws -> Result {
        guard let archive = archive else {
            return Result.infoUnreadable.adding(supplementary: archiveURL.path)
        }

        guard let workspace = defaultWorkspace else {
            return .badArguments
        }

        guard let user = user(for: workspace, shell: shell) else {
            return Result.noDefaultUser.adding(supplementary: "Set using \(CommandLine.name) \(description.name) --user <user> --set-default.")
        }

        if shell.arguments.flag("set-default") {
            setDefaultUser(user, for: workspace)
        }

        let exportedAppPath = exportURL.appendingPathComponent(archive.name)
        let ditto = DittoRunner(shell: shell)
        
        let zipResult = try ditto.zip(exportedAppPath, as: exportedZipURL)
        if zipResult.status != 0 {
            return Result.exportFailed.adding(runnerResult: zipResult)
        }

        let xcrun = XCRunRunner(shell: shell)
        let result = try xcrun.run(arguments: ["altool", "--notarize-app", "--primary-bundle-id", archive.identifier, "--username", user, "--password", "@keychain:AC_PASSWORD", "--file", exportedZipURL.path, "--output-format", "xml"])
        if result.status != 0 {
            return Result.notarizingFailed.adding(runnerResult: result)
        }

        shell.log("Requested notarization.")
        do {
            try result.stdout.write(to: notarizingReceiptURL, atomically: true, encoding: .utf8)
        } catch {
            return Result.savingNotarizationReceiptFailed.adding(supplementary: "\(error)")
        }

        return .ok
    }
}
