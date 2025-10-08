// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/02/20.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Files
import Foundation
import Runner

enum GeneralError: Error, CustomStringConvertible, Sendable, Equatable {
  case infoUnreadable(_ path: String)
  case missingWorkspace
  case apiKeyAndIssuer
  case noDefaultScheme(_ platform: String)
  case taggingFailed
  case noVersionTagAtHEAD

  public var description: String {
    switch self {
      case .infoUnreadable(let path): return "Couldn't read archive info.plist.\n\(path)"

      case .missingWorkspace: return "The workspace was not specified, and could not be inferred."

      case .taggingFailed: return "Tagging failed."

      case .apiKeyAndIssuer:
        return """
          You need to supply both --api-key and --api-issuer together.
          Either supply both values on the command line, or set default values in
          the .rt.json file:

          "settings": {
            "*": {
              "apiKey": "key-here",
              "apiIssuer": "issuer-here"
            },

          A corresponding .p8 key file should be stored in ~/.appstoreconnect/private_keys/
          See https://appstoreconnect.apple.com/access/api to generate a key.
          """

      case .noDefaultScheme(let platform):
        return """
          No scheme specified for \(platform).
          Either supply a value with --scheme <scheme>, or set a default value using \(CommandLine.name) set scheme <scheme> --platform \(platform)."
          """

      case .noVersionTagAtHEAD:
        return """
          No version tag found at HEAD.
          Please create a version tag before archiving using:
            \(CommandLine.name) tag --tag-version <version> [--increment-tag]
          """
    }
  }
}

class OptionParser {
  enum Requirement {
    case archive
    case workspace
  }

  var showOutput: Bool
  var showCommands: Bool
  var verbose: Bool
  var semaphore: DispatchSemaphore? = nil
  var error: Error? = nil

  let workspaceSettingsURL: URL
  var workspaceSettings: WorkspaceSettings

  var platform: String = ""
  var scheme: String = ""
  var apiKey: String = ""
  var apiIssuer: String = ""
  var package: String = ""
  var workspace: String = ""
  var archive: XcodeArchive!

  let git: GitRunner
  let rootURL: URL
  let homeURL = FileManager.default.homeDirectoryForCurrentUser
  var exportedZipURL: URL { return exportURL.appendingPathComponent("exported.zip") }
  var exportedAppURL: URL { return exportURL.appendingPathComponent(archive.name) }
  var exportedIPAURL: URL {
    return exportURL.appendingPathComponent(archive.shortName).appendingPathExtension(
      platform == "macOS" ? "pkg" : "ipa")
  }
  var apiKeyURL: URL {
    return homeURL.appendingPathComponent(".ssh").appendingPathComponent("AuthKey_\(apiKey)")
  }
  var exportOptionsURL: URL { return buildURL.appendingPathComponent("options.plist") }
  var changesURL: URL { return buildURL.appendingPathComponent("changes.txt") }
  var notarizingReceiptURL: URL { return exportURL.appendingPathComponent("receipt.xml") }
  var uploadingReceiptURL: URL { return uploadURL.appendingPathComponent("receipt.json") }
  var uploadingErrorsURL: URL { return uploadURL.appendingPathComponent("errors.log") }
  var buildURL: URL { return rootURL.appendingPathComponents([".build", platform]) }
  var archiveURL: URL { return buildURL.appendingPathComponent("archive.xcarchive") }
  var exportURL: URL { return buildURL.appendingPathComponent("export") }
  var uploadURL: URL { return buildURL.appendingPathComponent("upload") }
  var stapledURL: URL { return buildURL.appendingPathComponent("stapled") }
  var versionTag: String { return "v\(archive.version)-\(archive.build)-\(platform)" }

  var defaultWorkspace: String? {
    let url = URL(fileURLWithPath: ".")
    if let contents = try? FileManager.default.contentsOfDirectory(
      at: url, includingPropertiesForKeys: [],
      options: [.skipsPackageDescendants, .skipsSubdirectoryDescendants, .skipsHiddenFiles])
    {
      for item in contents {
        if item.pathExtension == "xcworkspace" {
          return item.lastPathComponent
        }
      }
    }
    return nil
  }

  init(
    root rootURL: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
    requires requirements: Set<Requirement> = [],
    options: CommonOptions,
    command: CommandConfiguration,
    scheme: SchemeOption? = nil,
    apiKey: ApiKeyOption? = nil,
    apiIssuer: ApiIssuerOption? = nil,
    platform: PlatformOption? = nil,
    setDefaultPlatform: Bool = true
  ) throws {
    let git = GitRunner()
    git.cwd = rootURL
    self.git = git

    self.rootURL = rootURL
    showOutput = options.showOutput
    showCommands = options.showCommands
    verbose = options.verbose
    package = rootURL.lastPathComponent
    if let platform = platform {
      self.platform = platform.platform ?? (setDefaultPlatform ? "macOS" : "")
    }

    // load settings from the .rt.json file if it exists
    workspaceSettingsURL = URL(filePath: ".rt.json")!
    workspaceSettings = (try? WorkspaceSettings.load(url: workspaceSettingsURL)) ?? WorkspaceSettings()

    // if we've specified the scheme, we also need the workspace
    if requirements.contains(.workspace) || scheme != nil {
      if let workspace = options.workspace ?? defaultWorkspace {
        self.workspace = workspace

        // migrate any old UserDefault settings to .rt.json
        if let knownScheme = scheme?.scheme {
          if workspaceSettings.migrateSettings(
            workspace: workspace,
            scheme: knownScheme,
            platform: self.platform
          ) {

            // write the settings to the .rt.json file
            try workspaceSettings.write(to: workspaceSettingsURL)
          }
        }
      } else {
        throw GeneralError.missingWorkspace
      }
    }

    if scheme != nil {
      if let scheme = scheme?.scheme ?? defaultScheme {
        self.scheme = scheme
      } else {
        throw GeneralError.noDefaultScheme(self.platform)
      }
    }

    if apiKey != nil {
      if let key = apiKey?.key ?? getSettings().apiKey {
        self.apiKey = key
      }
    }

    if apiIssuer != nil {
      if let issuer = apiIssuer?.issuer ?? getSettings().apiIssuer {
        self.apiIssuer = issuer
      }
    }

    if apiKey != nil || apiIssuer != nil {
      // one of api-key or api-issuer is missing
      if self.apiKey.isEmpty != self.apiIssuer.isEmpty {
        throw GeneralError.apiKeyAndIssuer
      }
    }

    if requirements.contains(.archive) {
      if let archive = XcodeArchive(url: archiveURL) {
        self.archive = archive
      } else {
        throw GeneralError.infoUnreadable(archiveURL.path)
      }
    }
  }

  func defaultKey(for key: String, platform: String) -> String {
    if platform.isEmpty {
      return "\(key).default.\(workspace)"
    } else {
      return "\(key).default.\(platform).\(workspace)"
    }
  }

  func getSettings() -> BasicSettings {
    return workspaceSettings.settings(scheme: scheme, platform: platform)
  }

  /// If no scheme is supplied, we'll try to guess one based on the workspace.
  var defaultScheme: String? {
    if let value = workspaceSettings.defaultScheme {
      return value
    }

    if let ws = defaultWorkspace {
      let url = URL(fileURLWithPath: ws)
      let name = url.deletingPathExtension().lastPathComponent
      log("No scheme supplied - guessing at “\(name)”.")
      return name
    }

    return nil
  }

  func log(_ message: String) {
    print(message)
  }

  func verbose(_ message: String) {
    if verbose {
      print(message)
    }
  }

  func fail(_ error: Error) {
    self.error = error
    // semaphore?.signal()
  }

}
