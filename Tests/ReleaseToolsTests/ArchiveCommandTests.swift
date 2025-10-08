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

  @Test func failsWithoutVersionTagAtHEAD() async throws {
    let repo = try makeTempDir()
    try await initGitRepo(at: repo)

    // Create a non-version tag (should not count)
    try await tag(at: repo, name: "some-tag")

    let originalDir = FileManager.default.currentDirectoryPath
    FileManager.default.changeCurrentDirectoryPath(repo.path)
    defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

    let options = try CommonOptions.parse([])
    let parsed = try OptionParser(options: options, command: ArchiveCommand.configuration)

    await #expect(throws: GeneralError.noVersionTagAtHEAD) {
      try await parsed.ensureVersionTagAtHEAD()
    }
  }

  @Test func succeedsWithVersionTagAtHEAD() async throws {
    let repo = try makeTempDir()
    try await initGitRepo(at: repo)

    // Create a platform-agnostic version tag
    try await tag(at: repo, name: "v1.2.3-42")

    let originalDir = FileManager.default.currentDirectoryPath
    FileManager.default.changeCurrentDirectoryPath(repo.path)
    defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

    let options = try CommonOptions.parse([])
    let parsed = try OptionParser(options: options, command: ArchiveCommand.configuration)

    // Should not throw
    try await parsed.ensureVersionTagAtHEAD()
  }

  @Test func ignoresPlatformSpecificTags() async throws {
    let repo = try makeTempDir()
    try await initGitRepo(at: repo)

    // Create only a platform-specific tag (should not count)
    try await tag(at: repo, name: "v1.2.3-42-iOS")

    let originalDir = FileManager.default.currentDirectoryPath
    FileManager.default.changeCurrentDirectoryPath(repo.path)
    defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

    let options = try CommonOptions.parse([])
    let parsed = try OptionParser(options: options, command: ArchiveCommand.configuration)

    await #expect(throws: GeneralError.noVersionTagAtHEAD) {
      try await parsed.ensureVersionTagAtHEAD()
    }
  }

  @Test func allowsMultipleTagsAtHEAD() async throws {
    let repo = try makeTempDir()
    try await initGitRepo(at: repo)

    // Create multiple tags at HEAD
    try await tag(at: repo, name: "v1.2.3-42")
    try await tag(at: repo, name: "v1.2.3-42-iOS")
    try await tag(at: repo, name: "release-tag")

    let originalDir = FileManager.default.currentDirectoryPath
    FileManager.default.changeCurrentDirectoryPath(repo.path)
    defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

    let options = try CommonOptions.parse([])
    let parsed = try OptionParser(options: options, command: ArchiveCommand.configuration)

    // Should not throw as long as there's at least one platform-agnostic version tag
    try await parsed.ensureVersionTagAtHEAD()
  }
}
