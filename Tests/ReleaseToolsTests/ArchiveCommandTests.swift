// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Tests on 08/10/25.
//  All code (c) 2025 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Runner
import Testing

@testable import ReleaseTools

@Suite(.serialized)
struct ArchiveCommandTests {

  // MARK: - Tests

  @Test func failsWithoutVersionTagAtHEAD() async throws {
    let repo = try await TestRepo()

    // Create a non-version tag (should not count)
    try await repo.tag(name: "some-tag")

    let originalDir = FileManager.default.currentDirectoryPath
    FileManager.default.changeCurrentDirectoryPath(repo.url.path)
    defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

    let options = try CommonOptions.parse([])
    let parsed = try OptionParser(options: options, command: ArchiveCommand.configuration)

    await #expect(throws: GeneralError.noVersionTagAtHEAD) {
      try await parsed.ensureVersionTagAtHEAD()
    }
  }

  @Test func succeedsWithVersionTagAtHEAD() async throws {
    let repo = try await TestRepo()

    // Create a platform-agnostic version tag
    try await repo.tag(name: "v1.2.3-42")

    let originalDir = FileManager.default.currentDirectoryPath
    FileManager.default.changeCurrentDirectoryPath(repo.url.path)
    defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

    let options = try CommonOptions.parse([])
    let parsed = try OptionParser(options: options, command: ArchiveCommand.configuration)

    // Should not throw
    try await parsed.ensureVersionTagAtHEAD()
  }

  @Test func ignoresPlatformSpecificTags() async throws {
    let repo = try await TestRepo()

    // Create only a platform-specific tag (should not count)
    try await repo.tag(name: "v1.2.3-42-iOS")

    let originalDir = FileManager.default.currentDirectoryPath
    FileManager.default.changeCurrentDirectoryPath(repo.url.path)
    defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

    let options = try CommonOptions.parse([])
    let parsed = try OptionParser(options: options, command: ArchiveCommand.configuration)

    await #expect(throws: GeneralError.noVersionTagAtHEAD) {
      try await parsed.ensureVersionTagAtHEAD()
    }
  }

  @Test func allowsMultipleTagsAtHEAD() async throws {
    let repo = try await TestRepo()

    // Create multiple tags at HEAD
    try await repo.tag(name: "v1.2.3-42")
    try await repo.tag(name: "v1.2.3-42-iOS")
    try await repo.tag(name: "release-tag")

    let originalDir = FileManager.default.currentDirectoryPath
    FileManager.default.changeCurrentDirectoryPath(repo.url.path)
    defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

    let options = try CommonOptions.parse([])
    let parsed = try OptionParser(options: options, command: ArchiveCommand.configuration)

    // Should not throw as long as there's at least one platform-agnostic version tag
    try await parsed.ensureVersionTagAtHEAD()
  }
}
