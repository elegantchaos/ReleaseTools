// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/02/20.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import CommandShell

extension URL {
    func appendingPathComponents(_ components: [String]) -> URL {
        var url = self
        for component in components {
            url.appendPathComponent(component)
        }
        return url
    }
}

extension Result {
    static let infoUnreadable = Result(200, "Couldn't read archive info.plist.")
    static let missingWorkspace = Result(201, "The workspace was not specified, and could not be inferred.")
    static let noDefaultUser = Result(202, "No default user set.")
    static let noDefaultScheme = Result(203, "No default scheme set.")
}

class RTCommand: Command {
    let platformOption = "--platform=<platform>"
    let platformOptionHelp = "The platform to build for. Should be one of: macOS, iOS, tvOS, watchOS."
    
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
    
    var exportedZipURL: URL { return exportURL.appendingPathComponent("exported.zip") }
    var notarizingReceiptURL: URL { return exportURL.appendingPathComponent("receipt.xml") }

    var buildURL: URL {
        return rootURL.appendingPathComponents([".build", platform])
    }
    
    var archiveURL: URL {
        return buildURL.appendingPathComponent("archive.xcarchive")
    }

    var exportURL: URL {
        return buildURL.appendingPathComponent("export")
    }
    
    var stapledURL: URL {
        return buildURL.appendingPathComponent("stapled")
    }

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
    
    var exportOptionsURL: URL {
        return rootURL.appendingPathComponents(["Sources", scheme, "Resources", "ExportOptions-\(platform).plist"])
    }
    
    enum Requirement {
        case workspace
        case scheme
        case user
        case archive
    }
    
    var workspace: String = ""
    var scheme: String = ""
    var platform: String = ""
    var user: String = ""
    var archive: XcodeArchive!
    
    func require(_ requirements: Set<Requirement>) -> Result {
        // add some implied requirements
        var expanded = requirements
        if requirements.contains(.scheme) || requirements.contains(.user) {
            expanded.insert(.workspace)
        }

        self.platform = shell.arguments.option("platform") ?? "macOS"

        if expanded.contains(.workspace) {
            if let workspace = defaultWorkspace {
                self.workspace = workspace
            } else {
                return .badArguments
            }
        }

        if expanded.contains(.scheme) {
            if let scheme = scheme(for: workspace) {
                self.scheme = scheme
                if shell.arguments.flag("set-default") {
                    setDefault(scheme, for: "scheme")
                }
            } else {
                return Result.noDefaultScheme.adding(supplementary: "Set using \(CommandLine.name) \(description.name) --scheme=<scheme> --set-default.")
            }
        }
        
        if expanded.contains(.user) {
            if let user = user(for: workspace) {
                self.user = user
                if shell.arguments.flag("set-default") {
                    UserDefaults.standard.set(user, forKey: "defaultUser")
                }
            } else {
                return Result.noDefaultUser.adding(supplementary: "Set using \(CommandLine.name) \(description.name) --user <user> --set-default.")
            }
        }

        if expanded.contains(.archive) {
            if let archive = XcodeArchive(url: archiveURL) {
                self.archive = archive
            } else {
                return Result.infoUnreadable.adding(supplementary: archiveURL.path)
            }
        }
        
        return .ok
    }
    
    func defaultKey(for key: String) -> String {
        return "\(key).default.\(platform).\(workspace)"
    }
    
    func getDefault(for key: String) -> String? {
        return UserDefaults.standard.string(forKey: defaultKey(for: key))
    }
    
    func setDefault(_ value: String, for key: String) {
        UserDefaults.standard.set(value, forKey: defaultKey(for: key))
    }
    
    func scheme(for workspace: String) -> String? {
        return shell.arguments.option("scheme") ?? getDefault(for: "scheme")
    }
    
    func user(for workspace: String) -> String? {
        return shell.arguments.option("user") ?? UserDefaults.standard.string(forKey: "defaultUser")
    }
    
    
}
