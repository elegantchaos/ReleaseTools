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
    
    let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let archiveURL = URL(fileURLWithPath: ".build/archive.xcarchive")
    let exportURL = URL(fileURLWithPath: ".build/export")
    let stapledURL = URL(fileURLWithPath: ".build/stapled")
    
    var archive: XcodeArchive? { return XcodeArchive(url: archiveURL) }
    var exportedZipURL: URL { return exportURL.appendingPathComponent("exported.zip") }
    var notarizingReceiptURL: URL { return exportURL.appendingPathComponent("receipt.xml") }

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
        let scheme = shell.arguments.argument("scheme")
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
