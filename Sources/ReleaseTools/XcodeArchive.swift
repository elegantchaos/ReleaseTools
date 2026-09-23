// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 18/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Coercion
import Foundation

/// Errors encountered while loading the metadata that identifies an Xcode archive.
enum XcodeArchiveError: Error, Equatable, LocalizedError {
  /// The archive metadata plist could not be read from the supplied path.
  case unreadableMetadata(URL)
  /// The archive metadata plist was not a valid property list dictionary.
  case invalidMetadata(URL)
  /// The archive metadata was missing values required by release commands.
  case missingRequiredMetadata(URL, [String])

  /// A user-facing description of the archive metadata failure.
  var errorDescription: String? {
    switch self {
      case .unreadableMetadata(let url):
        return "Couldn't read archive metadata.\n\(url.path)"

      case .invalidMetadata(let url):
        return "Archive metadata is not a valid property list dictionary.\n\(url.path)"

      case .missingRequiredMetadata(let url, let keys):
        let missingKeys = keys.map { "- \($0)" }.joined(separator: "\n")
        return "Archive metadata is missing required values:\n\(missingKeys)\n\n\(url.path)"
    }
  }
}

/// Metadata used to identify and publish an Xcode archive.
struct XcodeArchive {
  /// Archive metadata values required by release commands.
  private static let requiredMetadataKeys = [
    "ApplicationPath",
    "CFBundleVersion",
    "CFBundleShortVersionString",
    "CFBundleIdentifier",
    "Team",
  ]

  /// The build number recorded in the archive.
  let build: String
  /// The marketing version recorded in the archive.
  let version: String
  /// The archived application's file name.
  let name: String
  /// The archived application's name without its extension.
  let shortName: String
  /// A filesystem-safe lowercase version of the short name.
  let lowername: String
  /// The archived application's bundle identifier.
  let identifier: String
  /// The signing team recorded in the archive.
  let team: String

  /// Loads and validates release metadata from an Xcode archive directory.
  init(url: URL) throws {
    let infoURL = url.appending(path: "Info.plist")
    let data: Data
    do {
      data = try Data(contentsOf: infoURL)
    } catch {
      throw XcodeArchiveError.unreadableMetadata(infoURL)
    }

    let plist: Any
    do {
      plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
    } catch {
      throw XcodeArchiveError.invalidMetadata(infoURL)
    }

    guard let info = plist as? [String: Any] else {
      throw XcodeArchiveError.invalidMetadata(infoURL)
    }

    guard let applicationProperties = info["ApplicationProperties"] as? [String: Any] else {
      throw XcodeArchiveError.missingRequiredMetadata(infoURL, ["ApplicationProperties"])
    }

    let missingKeys = Self.requiredMetadataKeys.compactMap { key in
      applicationProperties[asString: key] == nil ? "ApplicationProperties.\(key)" : nil
    }
    guard missingKeys.isEmpty else {
      throw XcodeArchiveError.missingRequiredMetadata(infoURL, missingKeys)
    }

    guard
      let path = applicationProperties[asString: "ApplicationPath"],
      let build = applicationProperties[asString: "CFBundleVersion"],
      let version = applicationProperties[asString: "CFBundleShortVersionString"],
      let identifier = applicationProperties[asString: "CFBundleIdentifier"],
      let team = applicationProperties[asString: "Team"]
    else { fatalError("Validated archive metadata could not be read.") }

    self.init(version: version, build: build, path: path, identifier: identifier, team: team)
  }

  /// Creates archive metadata from already validated values.
  init(version: String, build: String, path: String, identifier: String, team: String) {
    self.build = build
    self.version = version
    let url = URL(fileURLWithPath: path)
    self.name = url.lastPathComponent
    self.shortName = url.deletingPathExtension().lastPathComponent
    self.lowername = shortName.lowercased().replacingOccurrences(of: " ", with: "")
    self.identifier = identifier
    self.team = team
  }

  /// The filename used for a versioned compressed archive.
  var versionedZipName: String { "\(lowername)-\(version)-\(build).zip" }

  /// The filename used for the latest compressed archive.
  var unversionedZipName: String { "\(lowername).zip" }
}
