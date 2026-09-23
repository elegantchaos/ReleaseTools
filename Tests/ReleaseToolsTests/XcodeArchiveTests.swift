// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 23/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Testing

@testable import ReleaseTools

/// Tests archive metadata parsing and its user-facing diagnostics.
struct XcodeArchiveTests {
  /// Parses valid archive metadata.
  @Test func parsesRequiredMetadata() throws {
    let archiveURL = try makeArchive()
    defer { try? FileManager.default.removeItem(at: archiveURL) }

    let archive = try XcodeArchive(url: archiveURL)

    #expect(archive.build == "42")
    #expect(archive.version == "1.2.3")
    #expect(archive.name == "Example.app")
    #expect(archive.identifier == "com.example.app")
    #expect(archive.team == "ABCDE12345")
  }

  /// Reports every missing required metadata key together.
  @Test func reportsMissingRequiredMetadata() throws {
    let archiveURL = try makeArchive(removing: ["CFBundleShortVersionString", "Team"])
    defer { try? FileManager.default.removeItem(at: archiveURL) }

    do {
      _ = try XcodeArchive(url: archiveURL)
      Issue.record("Expected missing archive metadata to throw.")
    } catch let error as XcodeArchive.Error {
      guard case .missingRequiredMetadata(let url, let keys) = error else {
        Issue.record("Expected missing metadata error, got \(error).")
        return
      }

      #expect(url == archiveURL.appending(path: "Info.plist"))
      #expect(
        keys == [
          "ApplicationProperties.CFBundleShortVersionString",
          "ApplicationProperties.Team",
        ])
    }
  }

  /// Reports a missing archive and tells the user how to create one.
  @Test func reportsMissingArchive() throws {
    let archiveURL = URL.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: archiveURL) }

    #expect(throws: XcodeArchive.Error.archiveNotFound(archiveURL)) {
      try XcodeArchive(url: archiveURL)
    }

    let description = XcodeArchive.Error.archiveNotFound(archiveURL).errorDescription ?? ""
    #expect(description.contains(archiveURL.path))
    #expect(description.contains("\(CommandLine.name) archive"))
  }

  /// Reports an archive whose metadata plist exists but cannot be read, keeping the reason.
  @Test func reportsUnreadableMetadata() throws {
    let archiveURL = URL.temporaryDirectory.appending(path: UUID().uuidString)
    let infoURL = archiveURL.appending(path: "Info.plist")
    defer { try? FileManager.default.removeItem(at: archiveURL) }
    // A directory in place of the plist exists on disk but cannot be read as data.
    try FileManager.default.createDirectory(at: infoURL, withIntermediateDirectories: true)

    do {
      _ = try XcodeArchive(url: archiveURL)
      Issue.record("Expected unreadable archive metadata to throw.")
    } catch let error as XcodeArchive.Error {
      guard case .unreadableMetadata(let url, let reason) = error else {
        Issue.record("Expected unreadable metadata error, got \(error).")
        return
      }

      #expect(url == infoURL)
      #expect(!reason.isEmpty)
      #expect(error.errorDescription?.contains(reason) == true)
    }
  }

  /// Lists each missing key in the user-facing description.
  @Test func describesMissingRequiredMetadata() {
    let infoURL = URL(fileURLWithPath: "/tmp/Example.xcarchive/Info.plist")
    let error = XcodeArchive.Error.missingRequiredMetadata(
      infoURL, ["ApplicationProperties.CFBundleShortVersionString", "ApplicationProperties.Team"])
    let description = error.errorDescription ?? ""

    #expect(description.contains("- ApplicationProperties.CFBundleShortVersionString"))
    #expect(description.contains("- ApplicationProperties.Team"))
    #expect(description.contains(infoURL.path))
  }

  /// Reports an archive with no application metadata dictionary.
  @Test func reportsMissingApplicationProperties() throws {
    let archiveURL = URL.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: archiveURL) }
    try FileManager.default.createDirectory(at: archiveURL, withIntermediateDirectories: true)
    let data = try PropertyListSerialization.data(fromPropertyList: [:], format: .xml, options: 0)
    try data.write(to: archiveURL.appending(path: "Info.plist"))

    do {
      _ = try XcodeArchive(url: archiveURL)
      Issue.record("Expected missing application properties to throw.")
    } catch let error as XcodeArchive.Error {
      #expect(
        error
          == .missingRequiredMetadata(
            archiveURL.appending(path: "Info.plist"),
            ["ApplicationProperties"]
          ))
    }
  }

  /// Reports an archive with malformed metadata.
  @Test func reportsInvalidMetadata() throws {
    let archiveURL = URL.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: archiveURL) }
    try FileManager.default.createDirectory(at: archiveURL, withIntermediateDirectories: true)
    try Data("not a property list".utf8).write(to: archiveURL.appending(path: "Info.plist"))

    do {
      _ = try XcodeArchive(url: archiveURL)
      Issue.record("Expected invalid archive metadata to throw.")
    } catch let error as XcodeArchive.Error {
      #expect(error == .invalidMetadata(archiveURL.appending(path: "Info.plist")))
    }
  }

  /// Builds a disposable archive with configurable application properties.
  private func makeArchive(removing keys: Set<String> = []) throws -> URL {
    let archiveURL = URL.temporaryDirectory.appending(path: UUID().uuidString)
    let infoURL = archiveURL.appending(path: "Info.plist")
    try FileManager.default.createDirectory(at: archiveURL, withIntermediateDirectories: true)

    var applicationProperties: [String: String] = [
      "ApplicationPath": "Applications/Example.app",
      "CFBundleVersion": "42",
      "CFBundleShortVersionString": "1.2.3",
      "CFBundleIdentifier": "com.example.app",
      "Team": "ABCDE12345",
    ]
    keys.forEach { applicationProperties.removeValue(forKey: $0) }

    let info = ["ApplicationProperties": applicationProperties]
    let data = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
    try data.write(to: infoURL)
    return archiveURL
  }
}
