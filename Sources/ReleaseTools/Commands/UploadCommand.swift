// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 25/02/20.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import CommandShell
import Runner

extension Result {
    static let uploadingFailed = Result(620, "Uploading failed.")
    static let savingUploadReceiptFailed = Result(621, "Saving upload receipt failed.")
}

class UploadCommand: RTCommand {
    
    override var description: Command.Description {
        return Description(
            name: "upload",
            help: "Upload the archived app to Apple Connect portal for processing.",
            usage: ["[\(userOption) [\(setDefaultOption)]] [\(platformOption)]"],
            options: [
                platformOption: platformOptionHelp,
                userOption: userOptionHelp,
                setDefaultOption: setDefaultOptionHelp
            ],
            returns: [.uploadingFailed, .savingUploadReceiptFailed]
        )
    }
    
    override func run(shell: Shell) throws -> Result {
        
        let gotRequirements = require([.workspace, .user, .archive, .scheme])
        guard gotRequirements == .ok else {
            return gotRequirements
        }
        
        shell.log("Uploading archive to Apple Connect.")
        let xcrun = XCRunRunner(shell: shell)
        let result = try xcrun.run(arguments: ["altool", "--upload-app", "--username", user, "--password", "@keychain:AC_PASSWORD", "--file", exportedIPAURL.path, "--output-format", "xml"])
        if result.status != 0 {
            return Result.uploadingFailed.adding(runnerResult: result)
        }
        
        shell.log("Finished uploading.")
        do {
            try result.stdout.write(to: uploadingReceiptURL, atomically: true, encoding: .utf8)
        } catch {
            return Result.savingUploadReceiptFailed.adding(supplementary: "\(error)")
        }
        
        return .ok
    }
}
