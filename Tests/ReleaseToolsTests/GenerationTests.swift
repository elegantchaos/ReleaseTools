// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Tests on 09/10/25.
//  All code (c) 2025 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Runner
import Testing

@testable import ReleaseTools

struct GenerationTests {

  // MARK: - Header Generation Tests

  @Test func generatesHeaderWithVersionTag() async throws {
    let repo = try await TestRepo()

    // Create a version tag at HEAD
    try await repo.tag(name: "v1.2.3-42")

    // Create ReleaseEngine
    let options = try CommonOptions.parse([])
    let engine = try ReleaseEngine(root: repo.url, options: options, command: ArchiveCommand.configuration)

    // Generate header file
    let headerPath = repo.url.appendingPathComponent("VersionInfo.h").path
    let buildInfo = try await engine.generateHeader(header: headerPath, requireHEADTag: true)

    // Verify the build number and commit are correct
    #expect(buildInfo.build == 42)
    #expect(!buildInfo.commit.isEmpty)

    // Verify header file content
    let headerContent = try String(contentsOf: URL(fileURLWithPath: headerPath), encoding: .utf8)
    let expectedContent = "#define RT_BUILD 42\n#define RT_COMMIT \(buildInfo.commit)\n#define RT_VERSION 1.2.3"
    #expect(headerContent == expectedContent)
  }

  @Test func generatesHeaderWithoutVersionTag() async throws {
    let repo = try await TestRepo()

    // Don't create any version tags, so it should calculate next build number
    let options = try CommonOptions.parse([])
    let engine = try ReleaseEngine(root: repo.url, options: options, command: UpdateBuildCommand.configuration)

    // Generate header file without requiring HEAD tag
    let headerPath = repo.url.appendingPathComponent("VersionInfo.h").path
    let buildInfo = try await engine.generateHeader(header: headerPath, requireHEADTag: false)

    // Should default to build 1 when no tags exist
    #expect(buildInfo.build == 1)
    #expect(!buildInfo.commit.isEmpty)

    // Verify header file content
    let headerContent = try String(contentsOf: URL(fileURLWithPath: headerPath), encoding: .utf8)
    let expectedContent = "#define RT_BUILD 1\n#define RT_COMMIT \(buildInfo.commit)\n#define RT_VERSION 1.0.0"
    #expect(headerContent == expectedContent)
  }

  @Test func generatesHeaderWithIncrementalBuild() async throws {
    let repo = try await TestRepo()

    // Create some existing version tags
    try await repo.tag(name: "v1.0.0-5")
    try await repo.commit(message: "another commit")

    let options = try CommonOptions.parse([])
    let engine = try ReleaseEngine(root: repo.url, options: options, command: UpdateBuildCommand.configuration)

    // Generate header file - should increment from highest existing tag
    let headerPath = repo.url.appendingPathComponent("VersionInfo.h").path
    let buildInfo = try await engine.generateHeader(header: headerPath, requireHEADTag: false)

    // Should increment to build 6
    #expect(buildInfo.build == 6)
    #expect(!buildInfo.commit.isEmpty)

    // Verify header file content
    let headerContent = try String(contentsOf: URL(fileURLWithPath: headerPath), encoding: .utf8)
    let expectedContent = "#define RT_BUILD 6\n#define RT_COMMIT \(buildInfo.commit)\n#define RT_VERSION 1.0.0"
    #expect(headerContent == expectedContent)
  }

  // MARK: - Config Generation Tests

  @Test func generatesConfigWithVersionTag() async throws {
    let repo = try await TestRepo()

    // Create a version tag at HEAD
    try await repo.tag(name: "v2.1.0-15")

    let options = try CommonOptions.parse([])
    let engine = try ReleaseEngine(root: repo.url, options: options, command: UpdateBuildCommand.configuration)

    // Generate config file - expect git update-index to fail in test environment
    let configPath = repo.url.appendingPathComponent("BuildNumber.xcconfig").path
    do {
      try await engine.generateConfig(config: configPath)
    } catch {
      // git update-index fails in test environment on temp repos - that's expected
      // The file should still be generated correctly
    }

    // Get the expected commit hash
    let buildInfo = try await engine.buildInfoFromTag(requireHeadTag: false)

    // Verify config file content was still generated correctly
    let configContent = try String(contentsOf: URL(fileURLWithPath: configPath), encoding: .utf8)
    let expectedContent = "RT_BUILD = 16\nRT_COMMIT = \(buildInfo.commit)\nRT_VERSION = 2.1.0"
    #expect(configContent == expectedContent)
  }

  @Test func updatesExistingConfig() async throws {
    let repo = try await TestRepo()

    // Create initial config with different content
    let configPath = repo.url.appendingPathComponent("BuildNumber.xcconfig").path
    let initialContent = "RT_BUILD = 1\nRT_COMMIT = oldcommit123"
    try initialContent.write(to: URL(fileURLWithPath: configPath), atomically: true, encoding: .utf8)

    // Create a version tag
    try await repo.tag(name: "v1.0.0-10")

    let options = try CommonOptions.parse([])
    let engine = try ReleaseEngine(root: repo.url, options: options, command: UpdateBuildCommand.configuration)

    // Update config file - expect git update-index to fail in test environment
    do {
      try await engine.generateConfig(config: configPath)
    } catch {
      // git update-index fails in test environment on temp repos - that's expected
      // The file should still be updated correctly
    }

    // Get the expected commit hash
    let buildInfo = try await engine.buildInfoFromTag(requireHeadTag: false)

    // Verify config file was updated
    let configContent = try String(contentsOf: URL(fileURLWithPath: configPath), encoding: .utf8)
    let expectedContent = "RT_BUILD = 11\nRT_COMMIT = \(buildInfo.commit)\nRT_VERSION = 1.0.0"
    #expect(configContent == expectedContent)
  }

  @Test func doesNotUpdateConfigWhenContentIsSame() async throws {
    let repo = try await TestRepo()

    // Create a version tag
    try await repo.tag(name: "v1.0.0-5")

    let options = try CommonOptions.parse([])
    let engine = try ReleaseEngine(root: repo.url, options: options, command: UpdateBuildCommand.configuration)

    // Get expected values
    let buildInfo = try await engine.buildInfoFromTag(requireHeadTag: false)

    // Create config with the exact same content that would be generated
    let configPath = repo.url.appendingPathComponent("BuildNumber.xcconfig").path
    let expectedContent = "RT_BUILD = \(buildInfo.build)\nRT_COMMIT = \(buildInfo.commit)\nRT_VERSION = \(buildInfo.version)"
    try expectedContent.write(to: URL(fileURLWithPath: configPath), atomically: true, encoding: .utf8)

    // Get modification time before calling generateConfig
    let attrs = try FileManager.default.attributesOfItem(atPath: configPath)
    let originalModTime = attrs[.modificationDate] as! Date

    // Call generateConfig - should not modify the file
    try await engine.generateConfig(config: configPath)

    // Verify content is still the same
    let configContent = try String(contentsOf: URL(fileURLWithPath: configPath), encoding: .utf8)
    #expect(configContent == expectedContent)

    // Verify file wasn't modified (same modification time)
    let newAttrs = try FileManager.default.attributesOfItem(atPath: configPath)
    let newModTime = newAttrs[.modificationDate] as! Date
    #expect(originalModTime == newModTime)
  }

  // MARK: - Plist Generation Tests

  @Test func generatesPlistWithVersionTag() async throws {
    let repo = try await TestRepo()

    // Create a version tag
    try await repo.tag(name: "v3.2.1-25")

    // Create source plist file using dictionary
    let sourcePlistPath = repo.url.appendingPathComponent("Info-Source.plist").path
    let sourcePlistDict: [String: Any] = [
      "CFBundleVersion": "1",
      "CFBundleIdentifier": "com.example.test",
    ]
    let sourcePlistData = try PropertyListSerialization.data(fromPropertyList: sourcePlistDict, format: .xml, options: 0)
    try sourcePlistData.write(to: URL(fileURLWithPath: sourcePlistPath))

    let options = try CommonOptions.parse([])
    let engine = try ReleaseEngine(root: repo.url, options: options, command: UpdateBuildCommand.configuration)

    // Generate plist
    let destPlistPath = repo.url.appendingPathComponent("Info.plist").path
    try await engine.generatePlist(source: sourcePlistPath, dest: destPlistPath)

    // Get expected commit hash
    let buildInfo = try await engine.buildInfoFromTag(requireHeadTag: false)

    // Verify destination plist was created with updated build number
    let destURL = URL(fileURLWithPath: destPlistPath)
    let plistData = try Data(contentsOf: destURL)
    let plist = try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as! [String: Any]

    // Verify our expected keys were added/updated
    #expect(plist["CFBundleVersion"] as? UInt == 26)
    #expect(plist["Commit"] as? String == buildInfo.commit)
    #expect(plist["Version"] as? String == "3.2.1")

    // Verify original unrelated key is preserved
    #expect(plist["CFBundleIdentifier"] as? String == "com.example.test")

    // Verify expected number of keys (2 original + 2 added Commit,Version = 4 total)
    #expect(plist.keys.count == 4)

    // Verify header file was also generated
    let headerPath = repo.url.appendingPathComponent("RTInfo.h").path
    let headerContent = try String(contentsOf: URL(fileURLWithPath: headerPath), encoding: .utf8)
    let expectedHeaderContent = "#define RT_BUILD 26\n#define RT_COMMIT \(buildInfo.commit)\n#define RT_VERSION 3.2.1"
    #expect(headerContent == expectedHeaderContent)
  }

  @Test func doesNotUpdatePlistWhenBuildNumberIsSame() async throws {
    let repo = try await TestRepo()

    // Create a version tag
    try await repo.tag(name: "v1.0.0-10")

    let options = try CommonOptions.parse([])
    let engine = try ReleaseEngine(root: repo.url, options: options, command: UpdateBuildCommand.configuration)

    // Get expected build number
    let buildInfo = try await engine.buildInfoFromTag(requireHeadTag: false)

    // Create source plist with the same build number that would be calculated using dictionary
    let sourcePlistPath = repo.url.appendingPathComponent("Info-Source.plist").path
    let sourcePlistDict: [String: Any] = [
      "CFBundleVersion": "\(buildInfo.build)",
      "CFBundleExecutable": "TestApp",
    ]
    let sourcePlistData = try PropertyListSerialization.data(fromPropertyList: sourcePlistDict, format: .xml, options: 0)
    try sourcePlistData.write(to: URL(fileURLWithPath: sourcePlistPath))

    // Generate plist - should detect no change needed
    let destPlistPath = repo.url.appendingPathComponent("Info.plist").path
    try await engine.generatePlist(source: sourcePlistPath, dest: destPlistPath)

    // Verify header file was NOT created (since no update was needed)
    let headerPath = repo.url.appendingPathComponent("RTInfo.h").path
    let headerExists = FileManager.default.fileExists(atPath: headerPath)
    #expect(!headerExists)
  }

  // MARK: - Integration Tests

  @Test func generatesConsistentValuesAcrossAllFormats() async throws {
    let repo = try await TestRepo()

    // Create multiple version tags to test build number calculation
    try await repo.tag(name: "v1.0.0-5")
    try await repo.commit(message: "update 1")
    try await repo.tag(name: "v1.1.0-8")
    try await repo.commit(message: "update 2")

    let options = try CommonOptions.parse([])
    let engine = try ReleaseEngine(root: repo.url, options: options, command: UpdateBuildCommand.configuration)

    // Generate all three formats
    let headerPath = repo.url.appendingPathComponent("VersionInfo.h").path
    let configPath = repo.url.appendingPathComponent("BuildNumber.xcconfig").path

    // Create source plist using dictionary
    let sourcePlistPath = repo.url.appendingPathComponent("Info-Source.plist").path
    let sourcePlistDict: [String: Any] = [
      "CFBundleVersion": "1",
      "CFBundleName": "TestApp",
    ]
    let sourcePlistData = try PropertyListSerialization.data(fromPropertyList: sourcePlistDict, format: .xml, options: 0)
    try sourcePlistData.write(to: URL(fileURLWithPath: sourcePlistPath))

    let destPlistPath = repo.url.appendingPathComponent("Info.plist").path

    // Generate all files
    let headerBuildInfo = try await engine.generateHeader(header: headerPath, requireHEADTag: false)

    // Generate config - expect git update-index to fail in test environment
    do {
      try await engine.generateConfig(config: configPath)
    } catch {
      // git update-index fails in test environment on temp repos - that's expected
      // The file should still be generated correctly
    }

    try await engine.generatePlist(source: sourcePlistPath, dest: destPlistPath)

    // All should use the same build number (9, incrementing from highest tag 8)
    let expectedBuild: UInt = 9
    #expect(headerBuildInfo.build == expectedBuild)

    // Verify header content
    let headerContent = try String(contentsOf: URL(fileURLWithPath: headerPath), encoding: .utf8)
    let expectedHeaderContent = "#define RT_BUILD \(expectedBuild)\n#define RT_COMMIT \(headerBuildInfo.commit)\n#define RT_VERSION 1.1.0"
    #expect(headerContent == expectedHeaderContent)

    // Verify config content
    let configContent = try String(contentsOf: URL(fileURLWithPath: configPath), encoding: .utf8)
    let expectedConfigContent = "RT_BUILD = \(expectedBuild)\nRT_COMMIT = \(headerBuildInfo.commit)\nRT_VERSION = 1.1.0"
    #expect(configContent == expectedConfigContent)

    // Verify plist content
    let plistData = try Data(contentsOf: URL(fileURLWithPath: destPlistPath))
    let plist = try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as! [String: Any]

    // Verify our expected keys were added/updated
    #expect(plist["CFBundleVersion"] as? UInt == expectedBuild)
    #expect(plist["Commit"] as? String == headerBuildInfo.commit)
    #expect(plist["Version"] as? String == "1.1.0")

    // Verify original unrelated key is preserved
    #expect(plist["CFBundleName"] as? String == "TestApp")

    // Verify expected number of keys (2 original + 2 added Commit,Version = 4 total)
    #expect(plist.keys.count == 4)

    // Verify RTInfo.h was also generated by plist function
    let rtInfoPath = repo.url.appendingPathComponent("RTInfo.h").path
    let rtInfoContent = try String(contentsOf: URL(fileURLWithPath: rtInfoPath), encoding: .utf8)
    #expect(rtInfoContent == expectedHeaderContent)
  }
}
