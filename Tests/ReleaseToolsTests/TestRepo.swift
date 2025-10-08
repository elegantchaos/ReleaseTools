// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 08/10/25.
//  All code (c) 2025 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Runner
import Testing

@testable import ReleaseTools

/// A test git repository with helper methods for common operations
class TestRepo {
  /// The URL of the repository
  let url: URL
  var transcript: String = ""

  /// The original working directory before changing to this repo
  private let originalCwd: String

  /// The git runner configured for this repository
  let git: GitRunner

  /// Create a new test repository in a temporary directory
  init() async throws {
    // Save the original working directory
    self.originalCwd = FileManager.default.currentDirectoryPath

    // Create temp directory
    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("ReleaseToolsTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true)
    self.url = tempURL

    // Create git runner
    var env = ProcessInfo.processInfo.environment
    env.removeValue(forKey: "GIT_DIR")
    env.removeValue(forKey: "GIT_WORK_TREE")
    env.removeValue(forKey: "GIT_INDEX_FILE")
    let gitRunner = GitRunner(environment: env)
    gitRunner.cwd = tempURL
    self.git = gitRunner

    // Initialize git repo
    try await initGitRepo()
  }

  /// Initialize the git repository with initial commit
  private func initGitRepo() async throws {
    await checkedGit(["init"])
    await checkedGit(["config", "user.name", "Test User"])
    await checkedGit(["config", "user.email", "test@example.com"])
    await checkedGit(["config", "commit.gpgsign", "false"])
    await checkedGit(["config", "tag.gpgSign", "false"])
    try "initial".write(to: url.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
    await checkedGit(["add", "."])
    await checkedGit(["commit", "-m", "initial"])
    await checkedGit(["rev-parse", "--verify", "HEAD"])
  }

  /// Create a new commit in the repository
  func commit(message: String = "update") async throws {
    let filename = "file-\(UUID().uuidString).txt"
    let p = url.appendingPathComponent(filename)
    try message.write(to: p, atomically: true, encoding: .utf8)
    await checkedGit(["add", "."])
    await checkedGit(["commit", "-m", message])
  }

  /// Create a git tag at HEAD
  func tag(name: String) async throws {
    await checkedGit(["tag", name])
  }

  func headTags() async throws -> [String] {
    let result = await checkedGit(["tag", "--points-at", "HEAD"])
    let tags = result.stdout
      .split(separator: "\n")
      .map { String($0) }
    return tags
  }

  func headTagsContains(_ tags: [String]) async throws -> Bool {
    let existingTags = try await headTags()
    for tag in tags {
      if !existingTags.contains(tag) {
        return false
      }
    }
    return true
  }

  /// Run a git command with GitRunner and capture stdout/stderr/exit code
  @discardableResult
  private func runGit(_ args: [String]) async -> (stdout: String, stderr: String, state: RunState) {
    let session = git.run(args)
    let out = await session.stdout.string
    let err = await session.stderr.string
    let state = await session.waitUntilExit()
    return (out, err, state)
  }

  /// Run a git command and assert it succeeded. Returns the same tuple as runGit
  @discardableResult
  func checkedGit(_ args: [String], sourceLocation: SourceLocation = #_sourceLocation) async -> (stdout: String, stderr: String, state: RunState) {
    let r = await runGit(args)
    transcript += "> git \(args.joined(separator: " "))"
    transcript += r.stdout
    transcript += r.stderr

    #expect(r.state == .succeeded, Comment(rawValue: r.stderr), sourceLocation: sourceLocation)
    return r
  }

  /// Change the current working directory to this repository
  func chdir() {
    FileManager.default.changeCurrentDirectoryPath(url.path)
  }

  /// Restore the original working directory
  func restoreCwd() {
    FileManager.default.changeCurrentDirectoryPath(originalCwd)
  }

  deinit {
    // Restore the original working directory when the repo is deallocated
    FileManager.default.changeCurrentDirectoryPath(originalCwd)
  }
}
