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
}

class WaitForNotarizationCommand: RTCommand {
    override var description: Command.Description {
        return Description(
            name: "status",
            help: "Check the notarization status.",
            usage: ["[--user=<user> [--set-default]] [--request=<request-uuid>]"],
            options: ["--repo=<repo>": "The repository containing the appcast and updates."],
            returns: [.notarizingFailed, .fetchingNotarizationStatusFailed]
        )
    }
    
    func savedNotarizationReceipt() -> String? {
        let notarizingReceiptURL = exportURL.appendingPathComponent("receipt.xml")
        guard let data = try? Data(contentsOf: notarizingReceiptURL),
            let receipt = try? JSONSerialization.jsonObject(with: data, options: []) as? [String:Any],
            let upload = receipt["notarization-upload"] as? [String:String] else { return nil }
        
        return upload["RequestUUID"]
    }
    
    override func run(shell: Shell) throws -> Result {
        guard let workspace = defaultWorkspace else {
            return .badArguments
        }

        guard let user = user(for: workspace, shell: shell) else {
            return Result.noDefaultUser.adding(supplementary: "Set using \(CommandLine.name) \(description.name) --user <user> --set-default.")
        }

        if shell.arguments.flag("set-default") {
            setDefaultUser(user, for: workspace)
        }

        guard let requestUUID = shell.arguments.option("request") ?? savedNotarizationReceipt() else {
            return Result.loadingNotarizationReceiptFailed
        }
        
        DispatchQueue.main.async {
            self.check(request: requestUUID, user: user)
        }
        
        return .running
    }
    
    func check(request: String, user: String) {
        let xcrun = XCRunRunner(shell: shell)
        do {
            let result = try xcrun.run(arguments: ["altool", "--notarization-info", request, "--username", user, "--password", "@keychain:AC_PASSWORD", "--output-format", "xml"])
            if result.status != 0 {
                shell.exit(result: Result.fetchingNotarizationStatusFailed.adding(runnerResult: result))
            }

            if let data = result.stdout.data(using: .utf8),
                let receipt = try? JSONSerialization.jsonObject(with: data, options: []) as? [String:Any],
                let info = receipt["notarization-info"] as? [String:String],
                let status = info["Status"] {
                if status == "success" {
                    shell.exit(result: .ok)
                } else if status == "failed" {
                    shell.exit(result: Result.notarizationFailed.adding(supplementary: info["Status Message"] ?? ""))
                } else {
                    let nextCheck = DispatchTime.now().advanced(by: .seconds(10))
                    DispatchQueue.main.asyncAfter(deadline: nextCheck) {
                        self.check(request: request, user: user)
                    }
                }
            }
        } catch {
            shell.exit(result: Result.fetchingNotarizationStatusFailed.adding(supplementary: "\(error)"))
        }
    }
}
