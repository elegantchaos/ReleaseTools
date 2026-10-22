// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 09/10/2025.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Runner
import Testing

@testable import ReleaseTools

/// Checks generated headers, Xcode settings, and property lists against repository tags.
struct GenerationTests {
  /// A required HEAD tag produces matching C preprocessor definitions.
  @Test func generatesHeaderWithVersionTag() async throws {
    let repo = try await TestRepo()

    try await repo.tag(name: "v1.2.3-42")

    let options = try CommonOptions.parse([])
    let engine = try await ReleaseEngine(root: repo.url, options: options)

    let headerPath = repo.url.appendingPathComponent("VersionInfo.h").path
    let buildInfo = try await engine.generateHeader(header: headerPath, requireHEADTag: true)

    #expect(buildInfo.build == 42)
    #expect(buildInfo.commit.isEmpty == false)

    let headerContent = try String(contentsOf: URL(fileURLWithPath: headerPath), encoding: .utf8)
    let expectedContent = "#define RT_BUILD 42\n#define RT_COMMIT \(buildInfo.commit)\n#define RT_VERSION 1.2.3"
    #expect(headerContent == expectedContent)
  }

  /// Header generation calculates initial version metadata without a HEAD tag.
  @Test func generatesHeaderWithoutVersionTag() async throws {
    let repo = try await TestRepo()

    let options = try CommonOptions.parse([])
    let engine = try await ReleaseEngine(root: repo.url, options: options)

    let headerPath = repo.url.appendingPathComponent("VersionInfo.h").path
    let buildInfo = try await engine.generateHeader(header: headerPath, requireHEADTag: false)

    #expect(buildInfo.build == 1)
    #expect(buildInfo.commit.isEmpty == false)

    let headerContent = try String(contentsOf: URL(fileURLWithPath: headerPath), encoding: .utf8)
    let expectedContent = "#define RT_BUILD 1\n#define RT_COMMIT \(buildInfo.commit)\n#define RT_VERSION 1.0.0"
    #expect(headerContent == expectedContent)
  }

  /// Header generation increments the highest tagged build.
  @Test func generatesHeaderWithIncrementalBuild() async throws {
    let repo = try await TestRepo()

    try await repo.tag(name: "v1.0.0-5")
    try await repo.commit(message: "another commit")

    let options = try CommonOptions.parse([])
    let engine = try await ReleaseEngine(root: repo.url, options: options)

    let headerPath = repo.url.appendingPathComponent("VersionInfo.h").path
    let buildInfo = try await engine.generateHeader(header: headerPath, requireHEADTag: false)

    #expect(buildInfo.build == 6)
    #expect(buildInfo.commit.isEmpty == false)

    let headerContent = try String(contentsOf: URL(fileURLWithPath: headerPath), encoding: .utf8)
    let expectedContent = "#define RT_BUILD 6\n#define RT_COMMIT \(buildInfo.commit)\n#define RT_VERSION 1.0.0"
    #expect(headerContent == expectedContent)
  }

  /// Generated Xcode settings contain the next build and tagged version.
  @Test func generatesConfigWithVersionTag() async throws {
    let repo = try await TestRepo()

    try await repo.tag(name: "v2.1.0-15")

    let options = try CommonOptions.parse([])
    let engine = try await ReleaseEngine(root: repo.url, options: options)

    let configPath = repo.url.appendingPathComponent("BuildNumber.xcconfig").path
    do {
      try await engine.generateConfig(config: configPath)
    } catch let error as Runner.WrappedError where (error.error as? ReleaseEngine.Error) == .updatingIndexFailed {
      // The generated fixture is untracked; writing precedes the Git index update.
    }

    let buildInfo = try await engine.buildInfoFromTag(requireHeadTag: false)

    let configContent = try String(contentsOf: URL(fileURLWithPath: configPath), encoding: .utf8)
    let expectedContent = "RT_BUILD = 16\nRT_COMMIT = \(buildInfo.commit)\nRT_VERSION = 2.1.0"
    #expect(configContent == expectedContent)
  }

  /// Changed version metadata replaces existing Xcode settings.
  @Test func updatesExistingConfig() async throws {
    let repo = try await TestRepo()

    let configPath = repo.url.appendingPathComponent("BuildNumber.xcconfig").path
    let initialContent = "RT_BUILD = 1\nRT_COMMIT = oldcommit123"
    try initialContent.write(to: URL(fileURLWithPath: configPath), atomically: true, encoding: .utf8)

    try await repo.tag(name: "v1.0.0-10")

    let options = try CommonOptions.parse([])
    let engine = try await ReleaseEngine(root: repo.url, options: options)

    do {
      try await engine.generateConfig(config: configPath)
    } catch let error as Runner.WrappedError where (error.error as? ReleaseEngine.Error) == .updatingIndexFailed {
      // The generated fixture is untracked; writing precedes the Git index update.
    }

    let buildInfo = try await engine.buildInfoFromTag(requireHeadTag: false)

    let configContent = try String(contentsOf: URL(fileURLWithPath: configPath), encoding: .utf8)
    let expectedContent = "RT_BUILD = 11\nRT_COMMIT = \(buildInfo.commit)\nRT_VERSION = 1.0.0"
    #expect(configContent == expectedContent)
  }

  /// Matching Xcode settings preserve the file’s modification time.
  @Test func doesNotUpdateConfigWhenContentIsSame() async throws {
    let repo = try await TestRepo()

    try await repo.tag(name: "v1.0.0-5")

    let options = try CommonOptions.parse([])
    let engine = try await ReleaseEngine(root: repo.url, options: options)

    let buildInfo = try await engine.buildInfoFromTag(requireHeadTag: false)

    let configPath = repo.url.appendingPathComponent("BuildNumber.xcconfig").path
    let expectedContent = "RT_BUILD = \(buildInfo.build)\nRT_COMMIT = \(buildInfo.commit)\nRT_VERSION = \(buildInfo.version)"
    try expectedContent.write(to: URL(fileURLWithPath: configPath), atomically: true, encoding: .utf8)

    let attrs = try FileManager.default.attributesOfItem(atPath: configPath)
    let originalModTime = try #require(attrs[.modificationDate] as? Date)

    try await engine.generateConfig(config: configPath)

    let configContent = try String(contentsOf: URL(fileURLWithPath: configPath), encoding: .utf8)
    #expect(configContent == expectedContent)

    let newAttrs = try FileManager.default.attributesOfItem(atPath: configPath)
    let newModTime = try #require(newAttrs[.modificationDate] as? Date)
    #expect(originalModTime == newModTime)
  }

  /// Property-list generation writes metadata and preserves unrelated fields.
  @Test func generatesPlistWithVersionTag() async throws {
    let repo = try await TestRepo()

    try await repo.tag(name: "v3.2.1-25")

    let sourcePlistPath = repo.url.appendingPathComponent("Info-Source.plist").path
    let sourcePlistDict: [String: Any] = [
      "CFBundleVersion": "1",
      "CFBundleIdentifier": "com.example.test",
    ]
    let sourcePlistData = try PropertyListSerialization.data(fromPropertyList: sourcePlistDict, format: .xml, options: 0)
    try sourcePlistData.write(to: URL(fileURLWithPath: sourcePlistPath))

    let options = try CommonOptions.parse([])
    let engine = try await ReleaseEngine(root: repo.url, options: options)

    let destPlistPath = repo.url.appendingPathComponent("Info.plist").path
    try await engine.generatePlist(source: sourcePlistPath, dest: destPlistPath)

    let buildInfo = try await engine.buildInfoFromTag(requireHeadTag: false)

    let destURL = URL(fileURLWithPath: destPlistPath)
    let plistData = try Data(contentsOf: destURL)
    let plist = try #require(PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any])

    #expect(plist["CFBundleVersion"] as? UInt == 26)
    #expect(plist["Commit"] as? String == buildInfo.commit)
    #expect(plist["Version"] as? String == "3.2.1")

    #expect(plist["CFBundleIdentifier"] as? String == "com.example.test")

    #expect(plist.keys.count == 4)

    let headerPath = repo.url.appendingPathComponent("RTInfo.h").path
    let headerContent = try String(contentsOf: URL(fileURLWithPath: headerPath), encoding: .utf8)
    let expectedHeaderContent = "#define RT_BUILD 26\n#define RT_COMMIT \(buildInfo.commit)\n#define RT_VERSION 3.2.1"
    #expect(headerContent == expectedHeaderContent)
  }

  /// A matching source build leaves generation outputs absent.
  @Test func doesNotUpdatePlistWhenBuildNumberIsSame() async throws {
    let repo = try await TestRepo()

    try await repo.tag(name: "v1.0.0-10")

    let options = try CommonOptions.parse([])
    let engine = try await ReleaseEngine(root: repo.url, options: options)

    let buildInfo = try await engine.buildInfoFromTag(requireHeadTag: false)

    let sourcePlistPath = repo.url.appendingPathComponent("Info-Source.plist").path
    let sourcePlistDict: [String: Any] = [
      "CFBundleVersion": "\(buildInfo.build)",
      "CFBundleExecutable": "TestApp",
    ]
    let sourcePlistData = try PropertyListSerialization.data(fromPropertyList: sourcePlistDict, format: .xml, options: 0)
    try sourcePlistData.write(to: URL(fileURLWithPath: sourcePlistPath))

    let destPlistPath = repo.url.appendingPathComponent("Info.plist").path
    try await engine.generatePlist(source: sourcePlistPath, dest: destPlistPath)

    let headerPath = repo.url.appendingPathComponent("RTInfo.h").path
    let headerExists = FileManager.default.fileExists(atPath: headerPath)
    #expect(headerExists == false)
  }

  /// Header, Xcode settings, and property list agree on version metadata.
  @Test func generatesConsistentValuesAcrossAllFormats() async throws {
    let repo = try await TestRepo()

    try await repo.tag(name: "v1.0.0-5")
    try await repo.commit(message: "update 1")
    try await repo.tag(name: "v1.1.0-8")
    try await repo.commit(message: "update 2")

    let options = try CommonOptions.parse([])
    let engine = try await ReleaseEngine(root: repo.url, options: options)

    let headerPath = repo.url.appendingPathComponent("VersionInfo.h").path
    let configPath = repo.url.appendingPathComponent("BuildNumber.xcconfig").path

    let sourcePlistPath = repo.url.appendingPathComponent("Info-Source.plist").path
    let sourcePlistDict: [String: Any] = [
      "CFBundleVersion": "1",
      "CFBundleName": "TestApp",
    ]
    let sourcePlistData = try PropertyListSerialization.data(fromPropertyList: sourcePlistDict, format: .xml, options: 0)
    try sourcePlistData.write(to: URL(fileURLWithPath: sourcePlistPath))

    let destPlistPath = repo.url.appendingPathComponent("Info.plist").path

    let headerBuildInfo = try await engine.generateHeader(header: headerPath, requireHEADTag: false)

    do {
      try await engine.generateConfig(config: configPath)
    } catch let error as Runner.WrappedError where (error.error as? ReleaseEngine.Error) == .updatingIndexFailed {
      // The generated fixture is untracked; writing precedes the Git index update.
    }

    try await engine.generatePlist(source: sourcePlistPath, dest: destPlistPath)

    let expectedBuild: UInt = 9
    #expect(headerBuildInfo.build == expectedBuild)

    let headerContent = try String(contentsOf: URL(fileURLWithPath: headerPath), encoding: .utf8)
    let expectedHeaderContent = "#define RT_BUILD \(expectedBuild)\n#define RT_COMMIT \(headerBuildInfo.commit)\n#define RT_VERSION 1.1.0"
    #expect(headerContent == expectedHeaderContent)

    let configContent = try String(contentsOf: URL(fileURLWithPath: configPath), encoding: .utf8)
    let expectedConfigContent = "RT_BUILD = \(expectedBuild)\nRT_COMMIT = \(headerBuildInfo.commit)\nRT_VERSION = 1.1.0"
    #expect(configContent == expectedConfigContent)

    let plistData = try Data(contentsOf: URL(fileURLWithPath: destPlistPath))
    let plist = try #require(PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any])

    #expect(plist["CFBundleVersion"] as? UInt == expectedBuild)
    #expect(plist["Commit"] as? String == headerBuildInfo.commit)
    #expect(plist["Version"] as? String == "1.1.0")

    #expect(plist["CFBundleName"] as? String == "TestApp")

    #expect(plist.keys.count == 4)

    let rtInfoPath = repo.url.appendingPathComponent("RTInfo.h").path
    let rtInfoContent = try String(contentsOf: URL(fileURLWithPath: rtInfoPath), encoding: .utf8)
    #expect(rtInfoContent == expectedHeaderContent)
  }
}
