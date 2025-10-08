// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Tests on 24/09/25.
//  All code (c) 2025 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Runner
import Testing

@testable import ReleaseTools

struct BuildNumberTests {

  // MARK: - Helpers

  func makeTempDir() throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("ReleaseToolsTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  // Run a git command with GitRunner and capture stdout/stderr/exit code.
  @discardableResult
  func runGit(_ git: GitRunner, _ args: [String]) async -> (stdout: String, stderr: String, state: RunState) {
    let session = git.run(args)
    let state = await session.waitUntilExit()
    let out = await session.stdout.string
    let err = await session.stderr.string
    return (out, err, state)
  }

  // Run a git command and assert it succeeded. Returns the same tuple as runGit.
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

  // All tests removed: The build number calculation methods (nextBuildNumberAndCommit)
  // and options (--increment-tag, --offset, --explicit-build) have been deprecated.
  // The new workflow requires platform-agnostic tags to be created first at HEAD using
  // the `rt tag` command. Build numbers are now read from existing tags via
  // buildNumberAndCommitFromHEAD() rather than calculated.

  // TODO: Add tests for the new buildNumberAndCommitFromHEAD() method if needed.
}
