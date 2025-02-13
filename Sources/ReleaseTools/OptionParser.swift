// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/02/20.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Files
import Foundation
import Runner

enum GeneralError: Error, CustomStringConvertible, Sendable {
  case infoUnreadable(_ path: String)
  case missingWorkspace
  case noDefaultUser
  case apiKeyAndIssuer
  case userOrApiKey
  case noDefaultScheme(_ platform: String)
  case taggingFailed

  public var description: String {
    switch self {
      case .infoUnreadable(let path): return "Couldn't read archive info.plist.\n\(path)"

      case .missingWorkspace: return "The workspace was not specified, and could not be inferred."

      case .taggingFailed: return "Tagging failed."

      case .noDefaultUser:
        return """
          No user specified.
          Either supply a value with --user <user>, or set a default value using:

            \(CommandLine.name) set user <user>.

          A corresponding app-specific password should be stored in your keychain.
          See https://support.apple.com/en-us/HT204397 for more details.
          """

      case .apiKeyAndIssuer:
        return """
          You need to supply both --api-key and --api-issuer together.
          Either supply both values on the command line, or set default values using:

            \(CommandLine.name) set api-key <key>
            \(CommandLine.name) set api-issuer <issuer>

          A corresponding .p8 key file should be stored in ~/.appstoreconnect/private_keys/
          See https://appstoreconnect.apple.com/access/api to generate a key.
          """

      case .userOrApiKey:
        return """
          You need to supply either --user, or --api-key and --api-issuer together.
          If you are using --user, either supply it on the command line, or set a
          default value using:

            \(CommandLine.name) set user <user>

          A corresponding app-specific password should be stored in your keychain.
          See https://support.apple.com/en-us/HT204397 for more details.

          If you are using an api key, either supply both --api-key and --api-issuer
          on the command line, or set default values using:

            \(CommandLine.name) set api-key <key>
            \(CommandLine.name) set api-issuer <issuer>

          A corresponding .p8 key file should be stored in ~/.appstoreconnect/private_keys/
          See https://appstoreconnect.apple.com/access/api to generate a key.
          """

      case .noDefaultScheme(let platform):
        return """
          No scheme specified for \(platform).
          Either supply a value with --scheme <scheme>, or set a default value using \(CommandLine.name) set scheme <scheme> --platform \(platform)."
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
  var verbose: Bool
  var semaphore: DispatchSemaphore? = nil
  var error: Error? = nil

  var platform: String = ""
  var scheme: String = ""
  var user: String = ""
  var apiKey: String = ""
  var apiIssuer: String = ""
  var package: String = ""
  var workspace: String = ""
  var buildOffset: UInt = 0
  var incrementBuildTag: Bool = true
  var archive: XcodeArchive!

  let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
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
  var uploadingReceiptURL: URL { return exportURL.appendingPathComponent("receipt.xml") }
  var buildURL: URL { return rootURL.appendingPathComponents([".build", platform]) }
  var archiveURL: URL { return buildURL.appendingPathComponent("archive.xcarchive") }
  var exportURL: URL { return buildURL.appendingPathComponent("export") }
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
    requires requirements: Set<Requirement> = [],
    options: CommonOptions,
    command: CommandConfiguration,
    scheme: SchemeOption? = nil,
    user: UserOption? = nil,
    apiKey: ApiKeyOption? = nil,
    apiIssuer: ApiIssuerOption? = nil,
    platform: PlatformOption? = nil,
    buildOptions: BuildOptions? = nil,
    setDefaultPlatform: Bool = true
  ) throws {

    showOutput = options.showOutput
    verbose = options.verbose
    package = rootURL.lastPathComponent
    if let platform = platform {
      self.platform = platform.platform ?? (setDefaultPlatform ? "macOS" : "")
    }

    // remember the build offset if it was supplied
    if let buildOptions, let offset = buildOptions.offset {
      // ... on the command line
      buildOffset = offset

    } else if let setting = getDefault(for: "offset"), let offset = UInt(setting) {
      // ... or as a default setting
      buildOffset = offset
    }

    // remember the commit counting setting if it was supplied
    if let setting = getDefault(for: "increment-tag") {
      // ... as a default setting
      incrementBuildTag = setting == "true"
    }

    if let buildOptions, buildOptions.incrementTag {
      // ... a true value on the command line takes precedence
      incrementBuildTag = true
    }

    // if we've specified the scheme or user, we also need the workspace
    if requirements.contains(.workspace) || scheme != nil || user != nil {
      if let workspace = options.workspace ?? defaultWorkspace {
        self.workspace = workspace
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

    if user != nil {
      if let user = user?.user ?? getDefault(for: "user") {
        self.user = user
      } else if apiKey == nil {
        throw GeneralError.noDefaultUser
      }
    }

    if apiKey != nil {
      if let key = apiKey?.key ?? getDefault(for: "api-key") {
        self.apiKey = key
      }
    }

    if apiIssuer != nil {
      if let issuer = apiIssuer?.issuer ?? getDefault(for: "api-issuer") {
        self.apiIssuer = issuer
      }
    }

    if apiKey != nil {
      // one of api-key or api-issuer is missing
      if self.apiKey.isEmpty != self.apiIssuer.isEmpty {
        throw GeneralError.apiKeyAndIssuer
      }

      // neither user or api key has been provided - we need one
      if self.apiKey.isEmpty && self.user.isEmpty {
        throw GeneralError.userOrApiKey
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

  /// Read a default value from the settings.
  /// We look for a platform-specific value first, and fall back on a general value if that doesn't exist.
  func getDefault(for key: String) -> String? {
    // try platform specific key first, if the platform has been specified
    if !platform.isEmpty,
      let platformValue = UserDefaults.standard.string(forKey: defaultKey(for: key, platform: platform))
    {
      return platformValue
    }

    // fall back on general key
    if let generalValue = UserDefaults.standard.string(forKey: defaultKey(for: key, platform: "")) {
      return generalValue
    }

    return nil
  }

  /// If no scheme is supplied, we'll try to guess one based on the workspace.
  var defaultScheme: String? {
    if let value = getDefault(for: "scheme") {
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

  func setDefault(_ value: String, for key: String) {
    let key = defaultKey(for: key, platform: platform)
    UserDefaults.standard.set(value, forKey: key)
  }

  func clearDefault(for key: String) {
    let key = defaultKey(for: key, platform: platform)
    UserDefaults.standard.set(nil, forKey: key)
  }

  func log(_ message: String) {
    print(message)
  }

  func verbose(_ message: String) {
    if verbose {
      print(message)
    }
  }

  // func wait() throws {
  //   semaphore = DispatchSemaphore(value: 0)
  //   semaphore?.wait()

  //   if let error = error {
  //     throw error
  //   }
  // }

  // func done() {
  //   semaphore?.signal()
  // }

  func fail(_ error: Error) {
    self.error = error
    // semaphore?.signal()
  }
}
