// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Tests on 27/02/26.
//  All code (c) 2026 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Testing

@testable import ReleaseTools

struct ChangesCommandTests {

  @Test func defaultsToPreviousTagAndHead() async throws {
    let repo = try await TestRepo()
    try await repo.tag(name: "v1.0.0")
    try await repo.commit(message: "second commit")
    try await repo.commit(message: "third commit")

    let result = await repo.checkedRT(["changes"])

    #expect(result.stdout.contains("## Changes since v1.0.0"))
    #expect(result.stdout.contains("- second commit"))
    #expect(result.stdout.contains("- third commit"))
    #expect(result.stdout.contains("## Commits"))
    #expect(result.stdout.contains("Range: `v1.0.0..HEAD`"))
  }

  @Test func supportsExplicitStartAndEnd() async throws {
    let repo = try await TestRepo()
    try await repo.tag(name: "v1.0.0")
    try await repo.commit(message: "second commit")
    try await repo.tag(name: "v1.1.0")
    try await repo.commit(message: "third commit")

    let result = await repo.checkedRT(["changes", "--start", "v1.0.0", "--end", "v1.1.0"])

    #expect(result.stdout.contains("## Changes since v1.0.0"))
    #expect(result.stdout.contains("second commit"))
    #expect(!result.stdout.contains("third commit"))
    #expect(result.stdout.contains("Range: `v1.0.0..v1.1.0`"))
  }

  @Test func supportsAlternateRepository() async throws {
    let commandRepo = try await TestRepo()
    let dataRepo = try await TestRepo()
    try await dataRepo.tag(name: "v1.0.0")
    try await dataRepo.commit(message: "repo specific commit")

    let result = await commandRepo.checkedRT(["changes", "--repo", dataRepo.url.path])

    #expect(result.stdout.contains("## Changes since v1.0.0"))
    #expect(result.stdout.contains("repo specific commit"))
  }

  @Test func includesGitHubCommitAndDiffLinksByDefault() async throws {
    let repo = try await TestRepo()
    await repo.checkedGit(["remote", "add", "origin", "git@github.com:elegantchaos/ReleaseTools.git"])
    try await repo.tag(name: "v1.0.0")
    try await repo.commit(message: "linked commit")

    let result = await repo.checkedRT(["changes"])

    #expect(result.stdout.contains("https://github.com/elegantchaos/ReleaseTools/commit/"))
    #expect(result.stdout.contains("https://github.com/elegantchaos/ReleaseTools/compare/v1.0.0...HEAD"))
    #expect(result.stdout.contains("- linked commit"))
  }

  @Test func suppressesRangeAndLinksWhenRequested() async throws {
    let repo = try await TestRepo()
    await repo.checkedGit(["remote", "add", "origin", "git@github.com:elegantchaos/ReleaseTools.git"])
    try await repo.tag(name: "v1.0.0")
    try await repo.commit(message: "no links commit")

    let result = await repo.checkedRT(["changes", "--no-links", "--no-range"])

    #expect(!result.stdout.contains("https://github.com/"))
    #expect(!result.stdout.contains("_Range:"))
  }

  @Test func suppressesCommitsWhenRequested() async throws {
    let repo = try await TestRepo()
    try await repo.tag(name: "v1.0.0")
    try await repo.commit(message: "hidden commit")

    let result = await repo.checkedRT(["changes", "--no-commits"])

    #expect(result.stdout.contains("- hidden commit"))
    #expect(!result.stdout.contains("## Commits"))
    #expect(result.stdout.contains("_Range:"))
  }

  @Test func expandsMultilineCommitMessagesInTopList() async throws {
    let repo = try await TestRepo()
    try await repo.tag(name: "v1.0.0")
    await repo.checkedGit(["commit", "--allow-empty", "-m", "subject line", "-m", "detail line"])

    let result = await repo.checkedRT(["changes", "--no-commits", "--no-range"])

    #expect(result.stdout.contains("- subject line"))
    #expect(result.stdout.contains("  - detail line"))
  }

  @Test func summaryFlagPreservesChangesOutput() async throws {
    let repo = try await TestRepo()
    try await repo.tag(name: "v1.0.0")
    try await repo.commit(message: "summary commit")

    let result = await repo.checkedRT(["changes", "--summary"])

    #expect(result.stdout.contains("## Changes since v1.0.0"))
    #expect(result.stdout.contains("- summary commit"))
  }
}
