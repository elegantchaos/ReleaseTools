// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/02/20.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import CommandShell


extension Result {
    static let infoUnreadable = Result(200, "Couldn't read archive info.plist.")
    static let missingWorkspace = Result(201, "The workspace was not specified, and could not be inferred.")
    static let noDefaultUser = Result(202, "No default user set.")
    static let noDefaultScheme = Result(203, "No default scheme set.")
}

class RTCommand: Command {
    let requestOption = "--request=<uuid>"
    let requestOptionHelp = "The uuid of the notarization request. Defaults to the value previously stored by the `notarize` command."
    
    let showOutputOption = "--show-output"
    let showOutputOptionHelp = "Show the external commands that we're executing, and the output from them."
    
    let schemeOption = "--scheme=<scheme>"
    let schemeOptionHelp = "The scheme we're building."
    
    let setDefaultOption = "--set-default"
    let setDefaultOptionHelp = "Remember the value that was specified for the scheme/user, and use it as the default in future."
    
    let userOption = "--user=<username>"
    let userOptionHelp = "The App Store Connect user we're notarizing as."
    
    let updatesOption = "--updates=<path>"
    let updatesOptionHelp = "The local path to the updates folder inside the website repository. Defaults to `Dependencies/Website/updates`."
    
    let websiteOption = "--website-<path>"
    let websiteOptionHelp = "The local path to the repository containing the website, where the appcast and zip archives live. Defaults to `Dependencies/Website`."
    
    let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let archiveURL = URL(fileURLWithPath: ".build/archive.xcarchive")
    let exportURL = URL(fileURLWithPath: ".build/export")
    let stapledURL = URL(fileURLWithPath: ".build/stapled")
    
    var archive: XcodeArchive? { return XcodeArchive(url: archiveURL) }
    var exportedZipURL: URL { return exportURL.appendingPathComponent("exported.zip") }
    var notarizingReceiptURL: URL { return exportURL.appendingPathComponent("receipt.xml") }

    var updatesURL: URL {
        if let path = shell.arguments.option("updates") {
            return URL(fileURLWithPath: path)
        } else {
            return URL(fileURLWithPath: "Dependencies/Website/updates")
        }
    }
    
    var websiteURL: URL {
        if let path = shell.arguments.option("website") {
            return URL(fileURLWithPath: path)
        } else {
            return URL(fileURLWithPath: "Dependencies/Website/")
        }
    }

    var defaultWorkspace: String? {
        let url = URL(fileURLWithPath: ".")
        if let contents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [], options: [.skipsPackageDescendants, .skipsSubdirectoryDescendants, .skipsHiddenFiles]) {
            for item in contents {
                if item.pathExtension == "xcworkspace" {
                    return item.lastPathComponent
                }
            }
        }
        return nil
    }

    func defaultScheme(for workspace: String) -> String? {
        return UserDefaults.standard.string(forKey: "defaultScheme.\(workspace)")
    }

    func setDefaultScheme(_ scheme: String, for workspace: String) {
        UserDefaults.standard.set(scheme, forKey: "defaultScheme.\(workspace)")
    }
    
    func scheme(for workspace: String, shell: Shell) -> String? {
        let scheme = shell.arguments.option("scheme")
        return scheme.isEmpty ? defaultScheme(for: workspace) : scheme
    }

    func defaultUser(for workspace: String) -> String? {
        return UserDefaults.standard.string(forKey: "defaultUser.\(workspace)")
    }

    func setDefaultUser(_ scheme: String, for workspace: String) {
        UserDefaults.standard.set(scheme, forKey: "defaultUser.\(workspace)")
    }
    
    func user(for workspace: String, shell: Shell) -> String? {
        if let user = shell.arguments.option("user") {
            return user
        } else {
            return defaultUser(for: workspace)
        }
    }
    
    
}
