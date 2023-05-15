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
        commandName: "upload",
        abstract: "Upload the archived app to Apple Connect portal for processing."
    )

    @OptionGroup() var scheme: SchemeOption
    @OptionGroup() var user: UserOption
    @OptionGroup() var apiKey: ApiKeyOption
    @OptionGroup() var apiIssuer: ApiIssuerOption
    @OptionGroup() var platform: PlatformOption
    @OptionGroup() var options: CommonOptions

    func run() throws {
        let parsed = try OptionParser(
            requires: [.archive],
            options: options,
            command: Self.configuration,
            scheme: scheme,
            user: user,
            apiKey: apiKey,
            apiIssuer: apiIssuer,
            platform: platform
        )
        
        parsed.log("Uploading \(parsed.versionTag) to Apple Connect.")
        let xcrun = XCRunRunner(parsed: parsed)
        let uploadResult: Runner.Result
        if parsed.apiKey.isEmpty {
            // use username & password
            uploadResult = try xcrun.run(arguments: ["altool", "--upload-app", "--username", parsed.user, "--password", "@keychain:AC_PASSWORD", "--file", parsed.exportedIPAURL.path, "--output-format", "xml", "--type", parsed.platform])
        } else {
            // use api key and issuer
            uploadResult = try xcrun.run(arguments: ["altool", "--upload-app", "--apiIssuer", parsed.apiIssuer, "--apiKey", parsed.apiKey, "--file", parsed.exportedIPAURL.path, "--output-format", "xml", "--type", parsed.platform])
        }
        
        if uploadResult.status != 0 {
            throw UploadError.uploadingFailed(uploadResult)
        }
        
        parsed.log("Finished uploading.")
        do {
            try uploadResult.stdout.write(to: parsed.uploadingReceiptURL, atomically: true, encoding: .utf8)
        } catch {
            throw UploadError.savingUploadReceiptFailed(error)
        }
        
        parsed.log("Tagging.")
        let git = GitRunner()
        let tagResult = try git.sync(arguments: ["tag", parsed.versionTag, "-m", "Uploaded with \(CommandLine.name)"])
        if tagResult.status != 0 {
            throw GeneralError.taggingFailed(tagResult)
        }
    }
}
