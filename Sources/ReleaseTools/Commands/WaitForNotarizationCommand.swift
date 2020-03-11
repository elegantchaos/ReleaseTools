// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/02/20.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import ArgumentParser
import Runner

enum WaitForNotarizationError: Error {
    case fetchingNotarizationStatusFailed(_ result: Runner.Result)
    case fetchingNotarizationStatusThrew(_ error: Error)
    case loadingNotarizationReceiptFailed
    case notarizationFailed(_ output: String)
    case exportingNotarizedAppFailed(_ result: Runner.Result)
    case exportingNotarizedAppThrew(_ error: Error)
    case missingArchive


    public var description: String {
        switch self {
            case .fetchingNotarizationStatusFailed(let result): return "Fetching notarization status failed.\n\(result)"
            case .fetchingNotarizationStatusThrew(let error): return "Fetching notarization status failed.\n\(error)"
            case .loadingNotarizationReceiptFailed: return "Loading notarization receipt failed."
            case .notarizationFailed(let output): return "Notarization failed.\n\(output)"
            case .exportingNotarizedAppFailed(let result): return "Exporting notarized app failed.\n\(result)"
            case .exportingNotarizedAppThrew(let error): return "Exporting notarized app failed.\n\(error)"
            case .missingArchive: return "Exporting notarized app couldn't find archive."
        }
    }
}

struct WaitForNotarizationCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "wait",
        abstract: "Wait until notarization has completed."
    )

    @Option(help: "The uuid of the notarization request. Defaults to the value previously stored by the `notarize` command.") var request: String?
    
    @OptionGroup() var user: UserOption
    @OptionGroup() var platform: PlatformOption
    @OptionGroup() var options: CommonOptions

    func run() throws {
        let parsed = try OptionParser(
            requires: [.archive],
            options: options,
            command: Self.configuration,
            user: user,
            platform: platform
        )

        guard let requestUUID = request ?? savedNotarizationReceipt(parsed: parsed) else {
            throw WaitForNotarizationError.loadingNotarizationReceiptFailed
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            parsed.log("Requesting notarization status...")
            self.check(request: requestUUID, parsed: parsed)
        }
        
        try parsed.wait()

        parsed.log("Tagging.")
        let git = GitRunner()
        let tagResult = try git.sync(arguments: ["tag", parsed.versionTag, "-m", "Uploaded with \(CommandLine.name)"])
        if tagResult.status != 0 {
            throw GeneralError.taggingFailed(tagResult)
        }
    }

    func savedNotarizationReceipt(parsed: OptionParser) -> String? {
        let notarizingReceiptURL = parsed.exportURL.appendingPathComponent("receipt.xml")
        guard let data = try? Data(contentsOf: notarizingReceiptURL),
            let receipt = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String:Any],
            let upload = receipt["notarization-upload"] as? [String:String] else { return nil }
        
        return upload["RequestUUID"]
    }
    

    func exportNotarized(parsed: OptionParser) {
        parsed.log("Stapling notarized app.")
        
        do {
            let fm = FileManager.default
            try? fm.createDirectory(at: parsed.stapledURL, withIntermediateDirectories: true, attributes: nil)
            
            if let archive = parsed.archive {
                let stapledAppURL = parsed.stapledURL.appendingPathComponent(archive.name)
                try? fm.removeItem(at: stapledAppURL)
                try? fm.copyItem(at: parsed.exportedAppURL, to: stapledAppURL)
                let xcrun = XCRunRunner(parsed: parsed)
                let result = try xcrun.run(arguments: ["stapler", "staple", stapledAppURL.path])
                if result.status == 0 {
                    parsed.done()
                } else {
                    parsed.fail(WaitForNotarizationError.exportingNotarizedAppFailed(result))
                }
            } else {
                parsed.fail(WaitForNotarizationError.missingArchive)
            }
        } catch {
            parsed.fail(WaitForNotarizationError.exportingNotarizedAppThrew(error))
        }
    }
    
    func check(request: String, parsed: OptionParser) {
        let xcrun = XCRunRunner(parsed: parsed)
        do {
            let result = try xcrun.run(arguments: ["altool", "--notarization-info", request, "--username", parsed.user, "--password", "@keychain:AC_PASSWORD", "--output-format", "xml"])
            if result.status != 0 {
                parsed.fail(WaitForNotarizationError.fetchingNotarizationStatusFailed(result))
            }

            parsed.log("Received response.")
            if let data = result.stdout.data(using: .utf8),
                let receipt = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String:Any],
                let info = receipt["notarization-info"] as? [String:Any],
                let status = info["Status"] as? String {
                parsed.log("Status was \(status).")
                if status == "success" {
                    exportNotarized(parsed: parsed)
                    return
                } else if status == "invalid" {
                    let message = (info["Status Message"] as? String) ?? ""
                    var output = "\(message).\n"
                    if let logFile = info["LogFileURL"] as? String,
                        let url = URL(string: logFile),
                        let data = try? Data(contentsOf: url),
                        let log = try? JSONSerialization.jsonObject(with: data, options: []) as? [String:Any] {
                        let summary = (log["statusSummary"] as? String) ?? ""
                        output.append("\(summary).\n")
                        if let issues = log["issues"] as? [[String:Any]] {
                            var count = 1
                            for issue in issues {
                                let message = issue["message"] as? String ?? ""
                                let path = issue["path"] as? String ?? ""
                                let name = URL(fileURLWithPath: path).lastPathComponent
                                let severity = issue["severity"] as? String ?? ""
                                output.append("\n#\(count) \(name) (\(severity)):\n\(message)\n\(path)\n")
                                count += 1
                            }
                        }
                    }
                    
                    parsed.fail(WaitForNotarizationError.notarizationFailed(output))
                }
            }
        } catch {
            parsed.fail(WaitForNotarizationError.fetchingNotarizationStatusThrew(error))
        }

        let delay = 30
        let nextCheck = DispatchTime.now().advanced(by: .seconds(delay))
        parsed.log("Will retry in \(delay) seconds...")
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: nextCheck) {
            parsed.log("Retrying fetch of notarization status...")
            self.check(request: request, parsed: parsed)
        }

    }
}
