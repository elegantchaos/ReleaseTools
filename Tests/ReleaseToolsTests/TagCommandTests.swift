// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Tests on 08/10/25.
//  All code (c) 2025 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Runner
import Testing

@testable import ReleaseTools

struct TagCommandTests {

  // MARK: - Tests

  @Test func createsTagWithExplicitVersion() async throws {
    let repo = try await TestRepo()

    // Run the tag command with explicit version and build number
    await repo.checkedRT(["tag", "--tag-version", "1.2.3", "--explicit-build", "42"])

    // Verify the tag was created with the explicit build number
    try await repo.expectHeadTagsContains(["v1.2.3-42"])
  }

  @Test func failsIfTagAlreadyExists() async throws {
    let repo = try await TestRepo()

    // Create a tag at HEAD
    try await repo.tag(name: "v1.0.0-1")

    // Verify the tag exists at HEAD
    let tags = try await repo.headTags()
    #expect(tags.contains("v1.0.0-1"), "Tag v1.0.0-1 should exist at HEAD, found: \(tags)")

    // Try to create another tag - should fail
    let result = await repo.runRT(["tag", "--tag-version", "1.0.0", "--explicit-build", "2"])

    // Command should fail
    #expect(result.state != .succeeded, "Command should have failed but succeeded")
    #expect(
      result.stderr.contains("already exists") || result.stderr.contains("tagAlreadyExists"),
      "Error message should mention tag already exists: \(result.stderr)")
  }

  @Test func allowsNonVersionTagsAtHEAD() async throws {
    let repo = try await TestRepo()

    // Create a non-version tag at HEAD
    try await repo.tag(name: "some-other-tag")

    // Run the tag command - should succeed despite the other tag
    await repo.checkedRT(["tag", "--tag-version", "1.0.0", "--explicit-build", "1"])

    // Verify both tags exist
    try await repo.expectHeadTagsContains(["v1.0.0-1", "some-other-tag"])
  }

  @Test func calculatesIncrementalBuildNumber() async throws {
    let repo = try await TestRepo()

    // Create an existing tag on a previous commit
    try await repo.tag(name: "v1.0.0-5")
    try await repo.commit(message: "second commit")

    // Run the tag command (always increments tag now)
    await repo.checkedRT(["tag", "--tag-version", "1.0.0"])

    // Verify the tag was created with build number 6
    try await repo.expectHeadTagsContains(["v1.0.0-6"])
  }

  @Test func convertsFromPlatformSpecificTags() async throws {
    let repo = try await TestRepo()

    // Create platform-specific tags
    try await repo.tag(name: "v1.0.0-10-iOS")
    try await repo.tag(name: "v1.0.0-15-macOS")
    try await repo.commit(message: "second commit")

    // Run the tag command
    // It should find the highest platform-specific tag (15) and increment it
    await repo.checkedRT(["tag", "--tag-version", "1.0.1"])

    // Verify the tag was created with build number 16 (15 + 1)
    try await repo.expectHeadTagsContains(["v1.0.1-16"])
  }

  @Test func prefersPlatformSpecificOverAgnosticWhenHigher() async throws {
    let repo = try await TestRepo()

    // Create both platform-agnostic and platform-specific tags
    try await repo.tag(name: "v1.0.0-10")
    try await repo.tag(name: "v1.0.0-20-iOS")
    try await repo.commit(message: "second commit")

    // Run the tag command
    // It should use the highest build number (20 from iOS) and increment it
    await repo.checkedRT(["tag", "--tag-version", "1.0.1"])

    // Verify the tag was created with build number 21 (20 + 1)
    try await repo.expectHeadTagsContains(["v1.0.1-21"])
  }

  @Test func prefersAgnosticOverPlatformSpecificWhenHigher() async throws {
    let repo = try await TestRepo()

    // Create both platform-agnostic and platform-specific tags
    try await repo.tag(name: "v1.0.0-30")
    try await repo.tag(name: "v1.0.0-20-iOS")
    try await repo.commit(message: "second commit")

    // Run the tag command
    // It should use the highest build number (30 from agnostic) and increment it
    await repo.checkedRT(["tag", "--tag-version", "1.0.1"])

    // Verify the tag was created with build number 31 (30 + 1)
    try await repo.expectHeadTagsContains(["v1.0.1-31"])
  }
}
