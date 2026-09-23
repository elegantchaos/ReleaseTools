// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/02/2020.
//  Copyright © 2020 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Files
import Foundation
import Runner

/// Coordinates configuration, derived paths, and subprocess helpers for release commands.
final class ReleaseEngine {

  var showOutput: Bool
  var showCommands: Bool
  var verbose: Bool
  var semaphore: DispatchSemaphore? = nil
  var error: (any Swift.Error)? = nil

  let configPaths: RTConfigPaths
  var configReader: RTConfigReader

  var platform: String = ""
  var scheme: String = ""
  var apiKey: String = ""
  var apiIssuer: String = ""
  var package: String = ""
  var workspace: String = ""
  let git: GitRunner
  let rootURL: URL
  let homeURL = FileManager.default.homeDirectoryForCurrentUser
  var exportedZipURL: URL { exportURL.appending(path: "exported.zip") }
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

  /// The first workspace found at the repository root when one was not passed explicitly.
  var defaultWorkspace: String? {
    let url = rootURL
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
    options: CommonOptions,
    command: CommandConfiguration,
    scheme: SchemeOption? = nil,
    apiKey: ApiKeyOption? = nil,
    apiIssuer: ApiIssuerOption? = nil,
    platform: PlatformOption? = nil,
    setDefaultPlatform: Bool = true
  ) async throws {
    let git = GitRunner()
    git.cwd = rootURL
    self.git = git

    self.rootURL = rootURL
    self.configPaths = RTConfigPaths(
      rootURL: rootURL,
      homeURL: FileManager.default.homeDirectoryForCurrentUser
    )
    showOutput = options.showOutput
    showCommands = options.showCommands
    verbose = options.verbose
    package = rootURL.lastPathComponent
    if let platform = platform {
      self.platform = platform.platform ?? (setDefaultPlatform ? "macOS" : "")
    }

    try RTLegacyConfigMigrator(paths: configPaths).migrateIfNeeded()
    configReader = try await RTConfigReader(paths: configPaths, scheme: nil, platform: self.platform)

    // Commands that resolve schemes need a workspace before layered config can be finalized.
    if scheme != nil {
      if let workspace = options.workspace ?? defaultWorkspace {
        self.workspace = workspace
      } else {
        throw Error.missingWorkspace
      }
    }

    if scheme != nil {
      if let scheme = scheme?.scheme ?? defaultScheme {
        self.scheme = scheme
      } else {
        throw Error.noDefaultScheme(self.platform)
      }
    }

    configReader = try await RTConfigReader(
      paths: configPaths,
      scheme: self.scheme,
      platform: self.platform
    )

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
      // Reject partially configured App Store Connect credentials.
      if self.apiKey.isEmpty != self.apiIssuer.isEmpty {
        throw Error.apiKeyAndIssuer
      }
    }

  }

  /// Loads and validates the archive at the configured archive path.
  func requireArchive() throws -> XcodeArchive {
    try XcodeArchive(url: archiveURL)
  }

  /// Returns the exported application path for an archive.
  func exportedAppURL(for archive: XcodeArchive) -> URL {
    exportURL.appending(path: archive.name)
  }

  /// Returns the exported package path for an archive.
  func exportedPackageURL(for archive: XcodeArchive) -> URL {
    exportURL.appending(path: archive.shortName).appendingPathExtension(platform == "macOS" ? "pkg" : "ipa")
  }

  /// Returns the git tag assigned to an uploaded archive.
  func versionTag(for archive: XcodeArchive) -> String {
    "v\(archive.version)-\(archive.build)-\(platform)"
  }

  /// Effective release settings after layered config resolution.
  func getSettings() -> BasicSettings {
    configReader.settings
  }

  /// If no scheme is supplied, we'll try to guess one based on the workspace.
  var defaultScheme: String? {
    if let value = configReader.defaultScheme {
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

  /// Emits user-visible progress output.
  func log(_ message: String) {
    print(message)
  }

  /// Emits verbose output when requested by the caller.
  func verbose(_ message: String) {
    if verbose {
      print(message)
    }
  }

  /// Stores an error for later inspection by older command flows.
  func fail(_ error: any Swift.Error) {
    self.error = error
  }
}

extension ReleaseEngine {
  /// Common release workflow failures surfaced by the engine.
  enum Error: Swift.Error, LocalizedError, Sendable, Equatable {
    /// A command needed a workspace and no workspace could be inferred.
    case missingWorkspace
    /// App Store Connect credentials were supplied incompletely.
    case apiKeyAndIssuer
    /// A command needed a scheme and no default was configured.
    case noDefaultScheme(String)
    /// A release tag could not be created.
    case taggingFailed
    /// HEAD does not have a version tag.
    case noVersionTagAtHEAD
    /// A version tag already exists at HEAD.
    case versionTagAlreadyExists(BuildInfo)
    /// A supplied build number cannot be parsed as a positive integer.
    case invalidExplicitBuild(String)
    /// Reading the HEAD commit failed.
    case gettingCommitFailed
    /// Parsing the HEAD commit failed.
    case parsingCommitFailed
    /// Writing generated build configuration failed.
    case writingConfigFailed(String)

    /// Listing release tags failed.
    case gettingBuildFailed
    /// Updating git's index for generated configuration failed.
    case updatingIndexFailed

    /// A user-facing description of the release workflow failure.
    var errorDescription: String? {
      switch self {
        case .gettingBuildFailed: return "Failed to get the build number from git."
        case .updatingIndexFailed: return "Failed to tell git to ignore the config file."
        case .missingWorkspace:
          return "The workspace was not specified, and could not be inferred."
        case .taggingFailed:
          return "Tagging failed."
        case .apiKeyAndIssuer:
          return """
            You need to supply both --api-key and --api-issuer together.
            Either supply both values on the command line, or set default values in
            the .rt/config.json file:

            {
              "settings": {
                "apiKey": "key-here",
                "apiIssuer": "issuer-here"
              }
            }

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
              \(CommandLine.name) tag --explicit-version <version> [--increment-tag]
            """
        case .versionTagAlreadyExists(let info):
          return "A version tag already exists at HEAD: \(info)"
        case .invalidExplicitBuild(let value):
          return "Invalid explicit build number: \(value). Must be a positive integer."
        case .gettingCommitFailed:
          return "Failed to get the commit from git."
        case .parsingCommitFailed:
          return "Failed to parse the commit information from git."
        case .writingConfigFailed(let message):
          return "Failed to write the config file.\n\n\(message)"
      }
    }
  }
}
