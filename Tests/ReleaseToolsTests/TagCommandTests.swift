// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 08/10/2025.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Runner
import Testing

@testable import ReleaseTools

/// Exercises tag creation and rejection through the current build’s executable.
struct TagCommandTests {
  /// Explicit version and build options produce the requested tag.
  @Test func createsTagWithExplicitVersion() async throws {
    let repo = try await TestRepo()

    await repo.checkedRT(["tag", "--explicit-version", "1.2.3", "--explicit-build", "42"])

    try await repo.expectHeadTagsContains(["v1.2.3-42"])
  }

  /// Duplicate tags fail with the current executable’s readable version-tag message.
  @Test func failsIfTagAlreadyExists() async throws {
    let repo = try await TestRepo()

    try await repo.tag(name: "v1.0.0-1")

    let tags = try await repo.headTags()
    #expect(tags.contains("v1.0.0-1"), "Tag v1.0.0-1 should exist at HEAD, found: \(tags)")

    let result = await repo.runRT(["tag", "--explicit-version", "1.0.0", "--explicit-build", "2"])

    #expect(result.state != .succeeded, "Command should have failed but succeeded")
    let output = result.stdout + result.stderr
    #expect(
      output.contains("Error: A version tag already exists at HEAD: v1.0.0-1."),
      "Error message should mention tag already exists. stdout: \(result.stdout), stderr: \(result.stderr)")
  }

  /// Unrelated tags do not prevent creation of a release version tag.
  @Test func allowsNonVersionTagsAtHEAD() async throws {
    let repo = try await TestRepo()

    try await repo.tag(name: "some-other-tag")

    await repo.checkedRT(["tag", "--explicit-version", "1.0.0", "--explicit-build", "1"])

    try await repo.expectHeadTagsContains(["v1.0.0-1", "some-other-tag"])
  }

  /// Tag creation increments the highest existing build number.
  @Test func calculatesIncrementalBuildNumber() async throws {
    let repo = try await TestRepo()

    try await repo.tag(name: "v1.0.0-5")
    try await repo.commit(message: "second commit")

    await repo.checkedRT(["tag", "--explicit-version", "1.0.0"])

    try await repo.expectHeadTagsContains(["v1.0.0-6"])
  }

  /// Platform-specific tags contribute to the next shared build number.
  @Test func convertsFromPlatformSpecificTags() async throws {
    let repo = try await TestRepo()

    try await repo.tag(name: "v1.0.0-10-iOS")
    try await repo.tag(name: "v1.0.0-15-macOS")
    try await repo.commit(message: "second commit")

    await repo.checkedRT(["tag", "--explicit-version", "1.0.1"])

    try await repo.expectHeadTagsContains(["v1.0.1-16"])
  }

  /// A higher platform-specific build wins when creating a tag.
  @Test func prefersPlatformSpecificOverAgnosticWhenHigher() async throws {
    let repo = try await TestRepo()

    try await repo.tag(name: "v1.0.0-10")
    try await repo.tag(name: "v1.0.0-20-iOS")
    try await repo.commit(message: "second commit")

    await repo.checkedRT(["tag", "--explicit-version", "1.0.1"])

    try await repo.expectHeadTagsContains(["v1.0.1-21"])
  }

  /// A higher shared build wins when creating a tag.
  @Test func prefersAgnosticOverPlatformSpecificWhenHigher() async throws {
    let repo = try await TestRepo()

    try await repo.tag(name: "v1.0.0-30")
    try await repo.tag(name: "v1.0.0-20-iOS")
    try await repo.commit(message: "second commit")

    await repo.checkedRT(["tag", "--explicit-version", "1.0.1"])

    try await repo.expectHeadTagsContains(["v1.0.1-31"])
  }

  /// An inferred version follows the tag with the highest build number.
  @Test func usesVersionFromHighestTag() async throws {
    let repo = try await TestRepo()

    try await repo.tag(name: "v1.0.0-5")
    try await repo.tag(name: "v2.3.1-10")
    try await repo.commit(message: "new commit")

    await repo.checkedRT(["tag"])

    try await repo.expectHeadTagsContains(["v2.3.1-11"])
  }

  /// An untagged repository starts at version 1.0.0 and build 1.
  @Test func fallsBackToDefaultVersion() async throws {
    let repo = try await TestRepo()

    await repo.checkedRT(["tag"])

    try await repo.expectHeadTagsContains(["v1.0.0-1"])
  }

  /// A platform-specific tag supplies the inferred version when it has the highest build.
  @Test func usesVersionFromPlatformSpecificTag() async throws {
    let repo = try await TestRepo()

    try await repo.tag(name: "v3.5.0-15-iOS")
    try await repo.tag(name: "v3.5.0-10-macOS")
    try await repo.commit(message: "new commit")

    await repo.checkedRT(["tag"])

    try await repo.expectHeadTagsContains(["v3.5.0-16"])
  }
}
