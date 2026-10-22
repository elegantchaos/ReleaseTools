// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 08/10/2025.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Runner
import Testing

@testable import ReleaseTools

/// Checks build-number and version selection from repository tags.
struct VersionTagTests {
  /// A required HEAD version fails when no release tag is present.
  @Test func failsWithoutVersionTagAtHEAD() async throws {
    let repo = try await TestRepo()

    try await repo.tag(name: "some-tag")
    let options = try CommonOptions.parse([])
    let parsed = try await ReleaseEngine(root: repo.url, options: options)

    await #expect(throws: ReleaseEngine.Error.noVersionTagAtHEAD) {
      _ = try await parsed.versionTagAtHEAD()
    }
  }

  /// A shared HEAD tag supplies its version and build.
  @Test func succeedsWithVersionTagAtHEAD() async throws {
    let repo = try await TestRepo()

    try await repo.tag(name: "v1.2.3-42")

    let options = try CommonOptions.parse([])
    let parsed = try await ReleaseEngine(root: repo.url, options: options)

    _ = try await parsed.versionTagAtHEAD()
  }

  /// Platform-specific tags do not satisfy the shared HEAD-tag requirement.
  @Test func ignoresPlatformSpecificTags() async throws {
    let repo = try await TestRepo()

    try await repo.tag(name: "v1.2.3-42-iOS")
    let options = try CommonOptions.parse([])
    let parsed = try await ReleaseEngine(root: repo.url, options: options)

    await #expect(throws: ReleaseEngine.Error.noVersionTagAtHEAD) {
      _ = try await parsed.versionTagAtHEAD()
    }
  }

  /// Additional unrelated HEAD tags do not hide a valid release tag.
  @Test func allowsMultipleTagsAtHEAD() async throws {
    let repo = try await TestRepo()

    try await repo.tag(name: "v1.2.3-42")
    try await repo.tag(name: "v1.2.3-42-iOS")
    try await repo.tag(name: "release-tag")

    let options = try CommonOptions.parse([])
    let parsed = try await ReleaseEngine(root: repo.url, options: options)

    _ = try await parsed.versionTagAtHEAD()
  }

  /// An untagged repository calculates build 1.
  @Test func calculatesNextBuildNumberWithNoTags() async throws {
    let repo = try await TestRepo()

    let options = try CommonOptions.parse([])
    let parsed = try await ReleaseEngine(root: repo.url, options: options)

    let buildInfo = try await parsed.buildInfoFromTag(requireHeadTag: false)

    #expect(buildInfo.build == 1)

    #expect(buildInfo.commit.count == 40)
    #expect(buildInfo.commit.allSatisfy { $0.isHexDigit })
  }

  /// A shared tag supplies the baseline for the next build.
  @Test func calculatesNextBuildNumberFromPlatformAgnosticTag() async throws {
    let repo = try await TestRepo()

    try await repo.tag(name: "v1.0.0-5")
    try await repo.commit(message: "commit with no tag")

    let options = try CommonOptions.parse([])
    let parsed = try await ReleaseEngine(root: repo.url, options: options)

    let buildInfo = try await parsed.buildInfoFromTag(requireHeadTag: false)

    #expect(buildInfo.build == 6)

    #expect(buildInfo.commit.count == 40)
    #expect(buildInfo.commit.allSatisfy { $0.isHexDigit })
  }

  /// A platform-specific tag supplies the baseline for the next build.
  @Test func calculatesNextBuildNumberFromPlatformSpecificTag() async throws {
    let repo = try await TestRepo()

    try await repo.tag(name: "v1.0.0-10-iOS")
    try await repo.commit(message: "commit with no tag")

    let options = try CommonOptions.parse([])
    let parsed = try await ReleaseEngine(root: repo.url, options: options)

    let buildInfo = try await parsed.buildInfoFromTag(requireHeadTag: false)

    #expect(buildInfo.build == 11)

    #expect(buildInfo.commit.count == 40)
    #expect(buildInfo.commit.allSatisfy { $0.isHexDigit })
  }

  /// The highest build wins across multiple versions and platforms.
  @Test func calculatesNextBuildNumberFromMultipleTags() async throws {
    let repo = try await TestRepo()

    try await repo.tag(name: "v1.0.0-5")
    try await repo.tag(name: "v1.0.0-10-iOS")
    try await repo.tag(name: "v1.0.0-8-macOS")
    try await repo.tag(name: "v0.9.0-20")
    try await repo.commit(message: "commit with no tag")

    let options = try CommonOptions.parse([])
    let parsed = try await ReleaseEngine(root: repo.url, options: options)

    let buildInfo = try await parsed.buildInfoFromTag(requireHeadTag: false)

    #expect(buildInfo.build == 21)

    #expect(buildInfo.commit.count == 40)
    #expect(buildInfo.commit.allSatisfy { $0.isHexDigit })
  }

  /// Calculated build metadata retains the current HEAD commit.
  @Test func returnsCurrentHeadCommitWhenRequireHeadTagIsFalse() async throws {
    let repo = try await TestRepo()

    try await repo.tag(name: "v1.0.0-1")

    try await repo.commit(message: "new commit")

    let options = try CommonOptions.parse([])
    let parsed = try await ReleaseEngine(root: repo.url, options: options)

    let buildInfo = try await parsed.buildInfoFromTag(requireHeadTag: false)

    #expect(buildInfo.build == 2)

    let headResult = await repo.checkedGit(["rev-parse", "HEAD"])
    let headCommit = headResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    #expect(buildInfo.commit == headCommit)
  }

  /// A higher shared tag supplies the next build’s version.
  @Test func prefersAgnosticOverPlatformSpecificForNextBuild() async throws {
    let repo = try await TestRepo()

    try await repo.tag(name: "v1.0.0-30")
    try await repo.tag(name: "v1.0.0-20-iOS")
    try await repo.commit(message: "commit with no tag")

    let options = try CommonOptions.parse([])
    let parsed = try await ReleaseEngine(root: repo.url, options: options)

    let buildInfo = try await parsed.buildInfoFromTag(requireHeadTag: false)

    #expect(buildInfo.build == 31)
  }

  /// A higher platform-specific tag supplies the next build’s version.
  @Test func prefersPlatformSpecificOverAgnosticForNextBuild() async throws {
    let repo = try await TestRepo()

    try await repo.tag(name: "v1.0.0-10")
    try await repo.tag(name: "v1.0.0-25-macOS")
    try await repo.commit(message: "commit with no tag")

    let options = try CommonOptions.parse([])
    let parsed = try await ReleaseEngine(root: repo.url, options: options)

    let buildInfo = try await parsed.buildInfoFromTag(requireHeadTag: false)

    #expect(buildInfo.build == 26)
  }
}
