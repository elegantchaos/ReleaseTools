// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/02/20.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import CommandShell
import Runner

extension Result {
    static let fetchingNotarizationStatusFailed = Result(650, "Fetching notarization status failed.")
    static let loadingNotarizationReceiptFailed = Result(651, "Loading notarization receipt failed.")
    static let notarizationFailed = Result(652, "Notarization failed.")
    static let exportingNotarizedAppFailed = Result(653, "Exporting notarized app failed.")
}

class WaitForNotarizationCommand: RTCommand {
    override var description: Command.Description {
        return Description(
            name: "wait",
            help: "Wait until notarization has completed.",
            usage: ["[\(userOption) [\(setDefaultOption)]] [\(requestOption)]"],
            options: [
                requestOption: requestOptionHelp,
                setDefaultOption: setDefaultOptionHelp,
                userOption: userOptionHelp,
            ],
            returns: [.notarizingFailed, .fetchingNotarizationStatusFailed, .notarizationFailed, .exportingNotarizedAppFailed]
        )
    }
    
    func savedNotarizationReceipt() -> String? {
        let notarizingReceiptURL = exportURL.appendingPathComponent("receipt.xml")
        guard let data = try? Data(contentsOf: notarizingReceiptURL),
            let receipt = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String:Any],
            let upload = receipt["notarization-upload"] as? [String:String] else { return nil }
        
        return upload["RequestUUID"]
    }
    
    override func run(shell: Shell) throws -> Result {
        let gotRequirements = require([.workspace, .user])
        guard gotRequirements == .ok else {
            return gotRequirements
        }

        guard let requestUUID = shell.arguments.option("request") ?? savedNotarizationReceipt() else {
            return Result.loadingNotarizationReceiptFailed
        }
        
        DispatchQueue.main.async {
            shell.log("Requesting notarization status...")
            self.check(request: requestUUID, user: self.user)
        }
        
        return .running
    }
    
    func exportNotarized() {
        shell.log("Stapling notarized app.")
        
        do {
            let fm = FileManager.default
            try? fm.createDirectory(at: stapledURL, withIntermediateDirectories: true, attributes: nil)
            
            if let archive = archive {
                let exportedAppURL = exportURL.appendingPathComponent(archive.name)
                let stapledAppURL = stapledURL.appendingPathComponent(archive.name)
                try? fm.removeItem(at: stapledAppURL)
                try? fm.copyItem(at: exportedAppURL, to: stapledAppURL)
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

        let delay = 10
        let nextCheck = DispatchTime.now().advanced(by: .seconds(delay))
        shell.log("Will retry in \(delay) seconds...")
        DispatchQueue.main.asyncAfter(deadline: nextCheck) {
            shell.log("Retrying fetch of notarization status...")
            self.check(request: request, user: user)
        }

    }
}
