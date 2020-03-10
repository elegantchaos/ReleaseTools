// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/02/20.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import ArgumentParser
import Runner

enum WaitForNotarizationError: Error {
    case fetchingNotarizationStatusFailed
    case loadingNotarizationReceiptFailed
    case notarizationFailed
    case exportingNotarizedAppFailed

    public var description: String {
        switch self {
            case .fetchingNotarizationStatusFailed: return "Fetching notarization status failed."
            case .loadingNotarizationReceiptFailed: return "Loading notarization receipt failed."
            case .notarizationFailed: return "Notarization failed."
            case .exportingNotarizedAppFailed: return "Exporting notarized app failed."
        }
    }
}

struct WaitForNotarizationCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Wait until notarization has completed."
    )

    @Option(help: "The uuid of the notarization request. Defaults to the value previously stored by the `notarize` command.") var request: String?
    
    @OptionGroup var options: StandardOptions

    func run() throws {
        let parsed = try StandardOptionParser([.workspace, .user, .archive], options: options, name: "wait")

        guard let requestUUID = request ?? savedNotarizationReceipt(parsed: parsed) else {
            throw WaitForNotarizationError.loadingNotarizationReceiptFailed
        }
        
        DispatchQueue.main.async {
            self.shell.log("Requesting notarization status...")
            self.check(request: requestUUID, user: parsed.user)
        }
    }

    func savedNotarizationReceipt(parsed: StandardOptionParser) -> String? {
        let notarizingReceiptURL = parsed.exportURL.appendingPathComponent("receipt.xml")
        guard let data = try? Data(contentsOf: notarizingReceiptURL),
            let receipt = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String:Any],
            let upload = receipt["notarization-upload"] as? [String:String] else { return nil }
        
        return upload["RequestUUID"]
    }
    

    func exportNotarized(parsed: StandardOptionParser) {
        shell.log("Stapling notarized app.")
        
        do {
            let fm = FileManager.default
            try? fm.createDirectory(at: parsed.stapledURL, withIntermediateDirectories: true, attributes: nil)
            
            if let archive = parsed.archive {
                let stapledAppURL = parsed.stapledURL.appendingPathComponent(archive.name)
                try? fm.removeItem(at: stapledAppURL)
                try? fm.copyItem(at: parsed.exportedAppURL, to: stapledAppURL)
                let xcrun = XCRunRunner(shell: shell)
                let result = try xcrun.run(arguments: ["stapler", "staple", stapledAppURL.path])
                if result.status == 0 {
                    shell.exit(result: .ok)
                } else {
                    shell.exit(result: Result.exportingNotarizedAppFailed.adding(runnerResult: result))
                }
            }
        } catch {
            shell.exit(result: Result.exportingNotarizedAppFailed.adding(supplementary: "\(error)"))
        }
        shell.exit(result: Result.exportingNotarizedAppFailed)
    }
    
    func check(request: String, user: String) {
        let xcrun = XCRunRunner(shell: shell)
        do {
            let result = try xcrun.run(arguments: ["altool", "--notarization-info", request, "--username", user, "--password", "@keychain:AC_PASSWORD", "--output-format", "xml"])
            if result.status != 0 {
                shell.exit(result: Result.fetchingNotarizationStatusFailed.adding(runnerResult: result))
            }

            shell.log("Received response.")
            if let data = result.stdout.data(using: .utf8),
                let receipt = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String:Any],
                let info = receipt["notarization-info"] as? [String:Any],
                let status = info["Status"] as? String {
                shell.log("Status was \(status).")
                if status == "success" {
                    exportNotarized()
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
                    
                    shell.exit(result: Result.notarizationFailed.adding(supplementary: output))
                }
            }
        } catch {
            shell.exit(result: Result.fetchingNotarizationStatusFailed.adding(supplementary: "\(error)"))
        }

        let delay = 30
        let nextCheck = DispatchTime.now().advanced(by: .seconds(delay))
        shell.log("Will retry in \(delay) seconds...")
        DispatchQueue.main.asyncAfter(deadline: nextCheck) {
            shell.log("Retrying fetch of notarization status...")
            self.check(request: request, user: user)
        }

    }
}
