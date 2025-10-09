// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Tests on 08/10/25.
//  All code (c) 2025 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Runner
import Testing

@testable import ReleaseTools

struct VersionTagTests {

  // MARK: - Tests

  @Test func failsWithoutVersionTagAtHEAD() async throws {
    let repo = try await TestRepo()

    // Create a non-version tag (should not count)
    try await repo.tag(name: "some-tag")
    let options = try CommonOptions.parse([])
    let parsed = try ReleaseEngine(root: repo.url, options: options, command: ArchiveCommand.configuration)

    await #expect(throws: GeneralError.noVersionTagAtHEAD) {
      _ = try await parsed.versionTagAtHEAD()
    }
  }

  @Test func succeedsWithVersionTagAtHEAD() async throws {
    let repo = try await TestRepo()

    // Create a platform-agnostic version tag
    try await repo.tag(name: "v1.2.3-42")

    let options = try CommonOptions.parse([])
    let parsed = try ReleaseEngine(root: repo.url, options: options, command: ArchiveCommand.configuration)

    // Should not throw
    _ = try await parsed.versionTagAtHEAD()
  }

  @Test func ignoresPlatformSpecificTags() async throws {
    let repo = try await TestRepo()

    // Create only a platform-specific tag (should not count)
    try await repo.tag(name: "v1.2.3-42-iOS")
    let options = try CommonOptions.parse([])
    let parsed = try ReleaseEngine(root: repo.url, options: options, command: ArchiveCommand.configuration)

    await #expect(throws: GeneralError.noVersionTagAtHEAD) {
      _ = try await parsed.versionTagAtHEAD()
    }
  }

  @Test func allowsMultipleTagsAtHEAD() async throws {
    let repo = try await TestRepo()

    // Create multiple tags at HEAD
    try await repo.tag(name: "v1.2.3-42")
    try await repo.tag(name: "v1.2.3-42-iOS")
    try await repo.tag(name: "release-tag")

    let options = try CommonOptions.parse([])
    let parsed = try ReleaseEngine(root: repo.url, options: options, command: ArchiveCommand.configuration)

    // Should not throw as long as there's at least one platform-agnostic version tag
    _ = try await parsed.versionTagAtHEAD()
  }

  // MARK: - Tests for requireHeadTag = false

  @Test func calculatesNextBuildNumberWithNoTags() async throws {
    let repo = try await TestRepo()

    let options = try CommonOptions.parse([])
    let parsed = try ReleaseEngine(root: repo.url, options: options, command: ArchiveCommand.configuration)

    let (build, commit) = try await parsed.buildNumberAndCommit(requireHeadTag: false)

    // Should return build number 1 when no tags exist
    #expect(build == 1)

    // Verify commit SHA is valid (40 character hex string)
    #expect(commit.count == 40)
    #expect(commit.allSatisfy { $0.isHexDigit })
  }

  @Test func calculatesNextBuildNumberFromPlatformAgnosticTag() async throws {
    let repo = try await TestRepo()

    // Create a platform-agnostic tag
    try await repo.tag(name: "v1.0.0-5")
    try await repo.commit(message: "commit with no tag")

    let options = try CommonOptions.parse([])
    let parsed = try ReleaseEngine(root: repo.url, options: options, command: ArchiveCommand.configuration)

    let (build, commit) = try await parsed.buildNumberAndCommit(requireHeadTag: false)

    // Should return next build number (6)
    #expect(build == 6)

    // Verify commit SHA is valid
    #expect(commit.count == 40)
    #expect(commit.allSatisfy { $0.isHexDigit })
  }

  @Test func calculatesNextBuildNumberFromPlatformSpecificTag() async throws {
    let repo = try await TestRepo()

    // Create a platform-specific tag
    try await repo.tag(name: "v1.0.0-10-iOS")
    try await repo.commit(message: "commit with no tag")

    let options = try CommonOptions.parse([])
    let parsed = try ReleaseEngine(root: repo.url, options: options, command: ArchiveCommand.configuration)

    let (build, commit) = try await parsed.buildNumberAndCommit(requireHeadTag: false)

    // Should return next build number (11), converting from platform-specific
    #expect(build == 11)

    // Verify commit SHA is valid
    #expect(commit.count == 40)
    #expect(commit.allSatisfy { $0.isHexDigit })
  }

  @Test func calculatesNextBuildNumberFromMultipleTags() async throws {
    let repo = try await TestRepo()

    // Create multiple tags with different build numbers
    try await repo.tag(name: "v1.0.0-5")
    try await repo.tag(name: "v1.0.0-10-iOS")
    try await repo.tag(name: "v1.0.0-8-macOS")
    try await repo.tag(name: "v0.9.0-20")
    try await repo.commit(message: "commit with no tag")

    let options = try CommonOptions.parse([])
    let parsed = try ReleaseEngine(root: repo.url, options: options, command: ArchiveCommand.configuration)

    let (build, commit) = try await parsed.buildNumberAndCommit(requireHeadTag: false)

    // Should return next build number based on highest (20 + 1 = 21)
    #expect(build == 21)

    // Verify commit SHA is valid
    #expect(commit.count == 40)
    #expect(commit.allSatisfy { $0.isHexDigit })
  }

  @Test func returnsCurrentHeadCommitWhenRequireHeadTagIsFalse() async throws {
    let repo = try await TestRepo()

    // Create an initial tag
    try await repo.tag(name: "v1.0.0-1")

    // Create a new commit (so HEAD is different from the tag)
    try await repo.commit(message: "new commit")

    let options = try CommonOptions.parse([])
    let parsed = try ReleaseEngine(root: repo.url, options: options, command: ArchiveCommand.configuration)

    let (build, commit) = try await parsed.buildNumberAndCommit(requireHeadTag: false)

    // Should return next build number
    #expect(build == 2)

    // Verify it returns the current HEAD commit, not the tag's commit
    let headResult = await repo.checkedGit(["rev-parse", "HEAD"])
    let headCommit = headResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    #expect(commit == headCommit)
  }

  @Test func prefersAgnosticOverPlatformSpecificForNextBuild() async throws {
    let repo = try await TestRepo()

    // Create tags where platform-agnostic has higher build number
    try await repo.tag(name: "v1.0.0-30")
    try await repo.tag(name: "v1.0.0-20-iOS")
    try await repo.commit(message: "commit with no tag")

    let options = try CommonOptions.parse([])
    let parsed = try ReleaseEngine(root: repo.url, options: options, command: ArchiveCommand.configuration)

    let (build, _) = try await parsed.buildNumberAndCommit(requireHeadTag: false)

    // Should use the highest build number (30) and return 31
    #expect(build == 31)
  }

  @Test func prefersPlatformSpecificOverAgnosticForNextBuild() async throws {
    let repo = try await TestRepo()

    // Create tags where platform-specific has higher build number
    try await repo.tag(name: "v1.0.0-10")
    try await repo.tag(name: "v1.0.0-25-macOS")
    try await repo.commit(message: "commit with no tag")

    let options = try CommonOptions.parse([])
    let parsed = try ReleaseEngine(root: repo.url, options: options, command: ArchiveCommand.configuration)

    let (build, _) = try await parsed.buildNumberAndCommit(requireHeadTag: false)

    // Should use the highest build number (25) and return 26
    #expect(build == 26)
  }
}
