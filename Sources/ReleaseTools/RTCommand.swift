// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/02/20.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import URLExtensions
import ArgumentParser


enum ParserError: Error, CustomStringConvertible {
    case infoUnreadable(_ path: String)
    case missingWorkspace
    case noDefaultUser(_ command: String, _ name: String)
    case noDefaultScheme(_ command: String, _ name: String)

    public var description: String {
        switch self {
            case .infoUnreadable(let path): return "Couldn't read archive info.plist.\n\(path)"
            case .missingWorkspace: return "The workspace was not specified, and could not be inferred."
            case .noDefaultUser(let command, let name): return "No default user set. Set using \(command) \(name) --user <user> --set-default."
            case .noDefaultScheme(let command, let name): return "No default scheme set. Set using \(command) \(name) --scheme=<scheme> --set-default."
        }
    }
}

class StandardOptionParser {
    enum Requirement {
        case archive
    }
    
    var showOutput: Bool
    var verbose: Bool
    var semaphore: DispatchSemaphore? = nil
    var error: Error? = nil

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
    
    init(_ requirements: Set<Requirement> = [],
         options: CommonOptions,
         command: CommandConfiguration,
         scheme: SchemeOption? = nil,
         user: UserOption? = nil,
         platform: PlatformOption? = nil,
         setDefaultArgument: SetDefaultOption? = nil
    ) throws {

        showOutput = options.showOutput
        verbose = options.verbose
        package = rootURL.lastPathComponent
        if let platform = platform {
            self.platform = platform.platform ?? "macOS"
        }

        // if we've specified the scheme or user, we also need the workspace
        if scheme != nil || user != nil {
            if let workspace = defaultWorkspace {
                self.workspace = workspace
            } else {
                throw ParserError.missingWorkspace
            }
        }
        
        if scheme != nil {
            if let scheme = scheme?.scheme ?? getDefault(for: "scheme") {
                self.scheme = scheme
                if setDefaultArgument?.setDefault ?? false {
                    setDefault(scheme, for: "scheme")
                }
            } else {
                throw ParserError.noDefaultScheme("rt", command.commandName!) // TODO: get command name from somewhere
            }
        }
        
        if user != nil {
            if let user = user?.user ?? getDefault(for: "user") {
                self.user = user
                if setDefaultArgument?.setDefault ?? false {
                    UserDefaults.standard.set(user, forKey: "defaultUser")
                }
            } else {
                throw ParserError.noDefaultUser("rt", command.commandName!)
            }
        }
        
        if requirements.contains(.archive) {
            if let archive = XcodeArchive(url: archiveURL) {
                self.archive = archive
            } else {
                throw ParserError.infoUnreadable(archiveURL.path)
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

    func log(_ message: String) {
        print(message)
    }

    func verbose(_ message: String) {
        print(message)
    }
    
    func wait() throws {
        semaphore = DispatchSemaphore(value: 0)
        semaphore?.wait()
        
        if let error = error {
            throw error
        }
    }
    
    func done() {
        semaphore?.signal()
    }
    
    func fail(_ error: Error) {
        self.error = error
        semaphore?.signal()
    }
}
