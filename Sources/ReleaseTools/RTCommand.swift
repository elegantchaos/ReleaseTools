// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/02/20.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import CommandShell
import URLExtensions
import ArgumentParser

extension Result {
    static let infoUnreadable = Result(200, "Couldn't read archive info.plist.")
    static let missingWorkspace = Result(201, "The workspace was not specified, and could not be inferred.")
    static let noDefaultUser = Result(202, "No default user set.")
    static let noDefaultScheme = Result(203, "No default scheme set.")
}

struct StandardOptions: ParsableArguments {
    @Flag(help: "Remember the value that was specified for the scheme/user, and use it as the default in future.")
    var setDefault: Bool
    
    @Flag(help: "Show the external commands that we're executing, and the output from them.")
    var showOutput: Bool
    
    @Option(help: "The scheme we're building.")
    var scheme: String?
    
    @Option(help: "The platform to build for. Should be one of: macOS, iOS, tvOS, watchOS.")
    var platform: String?
    
    @Option(help: "The App Store Connect user we're notarizing as.")
    var user: String?

    @Option(help: "updates help")
    var updates: String?

    @Option(help: "website help")
    var website: String?
    
    var updatesURL: URL {
        if let path = updates {
            return URL(fileURLWithPath: path)
        } else {
            return URL(fileURLWithPath: "Dependencies/Website/updates")
        }
    }
    
    var websiteURL: URL {
        if let path = website {
            return URL(fileURLWithPath: path)
        } else {
            return URL(fileURLWithPath: "Dependencies/Website/")
        }
    }
}

struct StandardOptionParser {
    enum Requirement {
        case package
        case workspace
        case scheme
        case user
        case archive
    }
    
    var platform: String = ""
    var scheme: String = ""
    var user: String = ""
    var package: String = ""
    var workspace: String = ""
    var archive: XcodeArchive!
    
    let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    
    var exportedZipURL: URL { return exportURL.appendingPathComponent("exported.zip") }
    
    var exportedAppURL: URL { return exportURL.appendingPathComponent(archive.name) }
    var exportedIPAURL: URL { return exportURL.appendingPathComponent(scheme).appendingPathExtension("ipa") }
    
    var notarizingReceiptURL: URL { return exportURL.appendingPathComponent("receipt.xml") }
    
    var uploadingReceiptURL: URL { return exportURL.appendingPathComponent("receipt.xml") }
    
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
        return rootURL.appendingPathComponents(["Sources", package, "Resources", "ExportOptions-\(platform).plist"])
    }
    
    init(_ requirements: Set<Requirement>, options: StandardOptions, name: String) throws {
        // add some implied requirements
        var expanded = requirements
        if requirements.contains(.scheme) || requirements.contains(.user) {
            expanded.insert(.workspace)
        }
        
        self.platform = options.platform ?? "macOS"
        
        if expanded.contains(.package) {
            package = rootURL.lastPathComponent
        }
        
        if expanded.contains(.workspace) {
            if let workspace = defaultWorkspace {
                self.workspace = workspace
            } else {
                throw ValidationError("Couldn't extract workspace.")
            }
        }
        
        if expanded.contains(.scheme) {
            if let scheme = options.scheme ?? getDefault(for: "scheme") {
                self.scheme = scheme
                if options.setDefault {
                    setDefault(scheme, for: "scheme")
                }
            } else {
                throw ValidationError("No default scheme.")
//                return Result.noDefaultScheme.adding(supplementary: "Set using \(CommandLine.name) \(name) --scheme=<scheme> --set-default.")
            }
        }
        
        if expanded.contains(.user) {
            if let user = options.user ?? getDefault(for: "user") {
                self.user = user
                if options.setDefault {
                    UserDefaults.standard.set(user, forKey: "defaultUser")
                }
            } else {
                throw ValidationError("No default user.")
//                return Result.noDefaultUser.adding(supplementary: "Set using \(CommandLine.name) \(name) --user <user> --set-default.")
            }
        }
        
        if expanded.contains(.archive) {
            if let archive = XcodeArchive(url: archiveURL) {
                self.archive = archive
            } else {
                throw ValidationError("Info unreadable.")
//                return Result.infoUnreadable.adding(supplementary: archiveURL.path)
            }
        }
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


}
