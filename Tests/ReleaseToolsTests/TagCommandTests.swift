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
struct TagCommandTests {

  // MARK: - Helpers

  func makeTempDir() throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("ReleaseToolsTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  @discardableResult
  func runGit(_ git: GitRunner, _ args: [String]) async -> (stdout: String, stderr: String, state: RunState) {
    let session = git.run(args)
    let state = await session.waitUntilExit()
    let out = await session.stdout.string
    let err = await session.stderr.string
    return (out, err, state)
  }

  @discardableResult
  func assertGit(_ git: GitRunner, _ args: [String], sourceLocation: SourceLocation = #_sourceLocation) async -> (stdout: String, stderr: String, state: RunState) {
    let r = await runGit(git, args)
    #expect(r.state == .succeeded, Comment(rawValue: r.stderr), sourceLocation: sourceLocation)
    return r
  }

  func initGitRepo(at url: URL) async throws {
    let git = gitRunner(for: url)
    await assertGit(git, ["init"])
    await assertGit(git, ["config", "user.name", "Test User"])
    await assertGit(git, ["config", "user.email", "test@example.com"])
    await assertGit(git, ["config", "commit.gpgsign", "false"])
    await assertGit(git, ["config", "tag.gpgSign", "false"])
    try "initial".write(to: url.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
    await assertGit(git, ["add", "."])
    await assertGit(git, ["commit", "-m", "initial"])
    await assertGit(git, ["rev-parse", "--verify", "HEAD"])
  }

  func commit(at url: URL, message: String = "update") async throws {
    let git = gitRunner(for: url)
    let filename = "file-\(UUID().uuidString).txt"
    let p = url.appendingPathComponent(filename)
    try message.write(to: p, atomically: true, encoding: .utf8)
    await assertGit(git, ["add", "."])
    await assertGit(git, ["commit", "-m", message])
  }

  func tag(at url: URL, name: String) async throws {
    let git = gitRunner(for: url)
    await assertGit(git, ["tag", name])
  }

  func gitRunner(for repo: URL) -> GitRunner {
    var env = ProcessInfo.processInfo.environment
    env.removeValue(forKey: "GIT_DIR")
    env.removeValue(forKey: "GIT_WORK_TREE")
    env.removeValue(forKey: "GIT_INDEX_FILE")
    let git = GitRunner(environment: env)
    git.cwd = repo
    return git
  }

  // MARK: - Tests

  @Test func createsTagWithExplicitVersion() async throws {
    let repo = try makeTempDir()
    try await initGitRepo(at: repo)

    let git = gitRunner(for: repo)

    // Run the tag command with explicit version and build number
    var command = try TagCommand.parse([
      "--repo", repo.path,
      "--tag-version", "1.2.3",
      "--explicit-build", "42",
    ])
    try await command.run()

    // Verify the tag was created with the explicit build number
    let tags = await runGit(git, ["tag", "--points-at", "HEAD"])
    #expect(tags.stdout.contains("v1.2.3-42"))
  }

  @Test func failsIfTagAlreadyExists() async throws {
    let repo = try makeTempDir()
    try await initGitRepo(at: repo)

    // Create a tag at HEAD
    try await tag(at: repo, name: "v1.0.0-1")

    // Try to create another tag - should fail
    var command = try TagCommand.parse([
      "--repo", repo.path,
      "--tag-version", "1.0.0",
      "--explicit-build", "2",
    ])

    do {
      try await command.run()
      #expect(Bool(false), "Should have thrown TagError.tagAlreadyExists")
    } catch let error as TagError {
      switch error {
        case .tagAlreadyExists:
          #expect(true)
        default:
          #expect(Bool(false), "Should throw TagError.tagAlreadyExists, got: \(error)")
      }
    } catch {
      #expect(Bool(false), "Should throw TagError.tagAlreadyExists, got: \(error)")
    }
  }

  @Test func allowsNonVersionTagsAtHEAD() async throws {
    let repo = try makeTempDir()
    try await initGitRepo(at: repo)

    // Create a non-version tag at HEAD
    try await tag(at: repo, name: "some-other-tag")

    let git = gitRunner(for: repo)

    // Run the tag command - should succeed despite the other tag
    var command = try TagCommand.parse([
      "--repo", repo.path,
      "--tag-version", "1.0.0",
      "--explicit-build", "1",
    ])
    try await command.run()

    // Verify both tags exist
    let tags = await runGit(git, ["tag", "--points-at", "HEAD"])
    #expect(tags.stdout.contains("v1.0.0-1"))
    #expect(tags.stdout.contains("some-other-tag"))
  }

  @Test func calculatesIncrementalBuildNumber() async throws {
    let repo = try makeTempDir()
    try await initGitRepo(at: repo)

    // Create an existing tag on a previous commit
    try await tag(at: repo, name: "v1.0.0-5")
    try await commit(at: repo, message: "second commit")

    let git = gitRunner(for: repo)

    // Run the tag command (always increments tag now)
    var command = try TagCommand.parse([
      "--repo", repo.path,
      "--tag-version", "1.0.0",
    ])
    try await command.run()

    // Verify the tag was created with build number 6
    let tags = await runGit(git, ["tag", "--points-at", "HEAD"])
    #expect(tags.stdout.contains("v1.0.0-6"))
  }

  @Test func convertsFromPlatformSpecificTags() async throws {
    let repo = try makeTempDir()
    try await initGitRepo(at: repo)

    // Create platform-specific tags
    try await tag(at: repo, name: "v1.0.0-10-iOS")
    try await tag(at: repo, name: "v1.0.0-15-macOS")
    try await commit(at: repo, message: "second commit")

    let git = gitRunner(for: repo)

    // Run the tag command
    // It should find the highest platform-specific tag (15) and increment it
    let command = try TagCommand.parse([
      "--repo", repo.path,
      "--tag-version", "1.0.1",
    ])
    try await command.run()

    // Verify the tag was created with build number 16 (15 + 1)
    let tags = await runGit(git, ["tag", "--points-at", "HEAD"])
    #expect(tags.stdout.contains("v1.0.1-16"))
  }

  @Test func prefersPlatformSpecificOverAgnosticWhenHigher() async throws {
    let repo = try makeTempDir()
    try await initGitRepo(at: repo)

    // Create both platform-agnostic and platform-specific tags
    try await tag(at: repo, name: "v1.0.0-10")
    try await tag(at: repo, name: "v1.0.0-20-iOS")
    try await commit(at: repo, message: "second commit")

    let git = gitRunner(for: repo)

    // Run the tag command
    // It should use the highest build number (20 from iOS) and increment it
    let command = try TagCommand.parse([
      "--repo", repo.path,
      "--tag-version", "1.0.1",
    ])
    try await command.run()

    // Verify the tag was created with build number 21 (20 + 1)
    let tags = await runGit(git, ["tag", "--points-at", "HEAD"])
    #expect(tags.stdout.contains("v1.0.1-21"))
  }

  @Test func prefersAgnosticOverPlatformSpecificWhenHigher() async throws {
    let repo = try makeTempDir()
    try await initGitRepo(at: repo)

    // Create both platform-agnostic and platform-specific tags
    try await tag(at: repo, name: "v1.0.0-30")
    try await tag(at: repo, name: "v1.0.0-20-iOS")
    try await commit(at: repo, message: "second commit")

    let git = gitRunner(for: repo)

    // Run the tag command
    // It should use the highest build number (30 from agnostic) and increment it
    let command = try TagCommand.parse([
      "--repo", repo.path,
      "--tag-version", "1.0.1",
    ])
    try await command.run()

    // Verify the tag was created with build number 31 (30 + 1)
    let tags = await runGit(git, ["tag", "--points-at", "HEAD"])
    #expect(tags.stdout.contains("v1.0.1-31"))
  }
}
