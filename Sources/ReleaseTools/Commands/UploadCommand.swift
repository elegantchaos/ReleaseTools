// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 25/02/20.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import ArgumentParser
import Runner


enum UploadError: Error {
    case uploadingFailed(_ result: Runner.Result)
    case savingUploadReceiptFailed(_ error: Error)
    
    public var description: String {
        switch self {
            case .uploadingFailed(let result): return "Uploading failed.\n\(result)"
            case .savingUploadReceiptFailed(let error): return "Saving upload receipt failed.\n\(error)"
        }
    }
}

struct UploadCommand: ParsableCommand {
    
    static var configuration = CommandConfiguration(
        abstract: "Upload the archived app to Apple Connect portal for processing."
    )
    
    @OptionGroup var options: StandardOptions
    
    func run() throws {
        let parsed = try StandardOptionParser([.workspace, .user, .archive, .scheme], options: options, name: "upload")
        
        parsed.log("Uploading archive to Apple Connect.")
        let xcrun = XCRunRunner(parsed: parsed)
        let result = try xcrun.run(arguments: ["altool", "--upload-app", "--username", parsed.user, "--password", "@keychain:AC_PASSWORD", "--file", parsed.exportedIPAURL.path, "--output-format", "xml"])
        if result.status != 0 {
            throw UploadError.uploadingFailed(result)
        }
        
        parsed.log("Finished uploading.")
        do {
            try result.stdout.write(to: parsed.uploadingReceiptURL, atomically: true, encoding: .utf8)
        } catch {
            throw UploadError.savingUploadReceiptFailed(error)
        }
    }
}
