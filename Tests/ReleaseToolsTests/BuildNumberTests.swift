// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Tests on 24/09/25.
//  All code (c) 2025 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import XCTest

@testable import ReleaseTools

final class BuildNumberTests: XCTestCase {

  // MARK: - Helpers

  func makeTempDir() throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("ReleaseToolsTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  // Run a git command with GitRunner and capture stdout/stderr/exit code.
  @discardableResult
  func runGit(_ git: GitRunner, _ args: [String]) async -> (stdout: String, stderr: String, code: Int32) {
    let session = git.run(args)
    let state = await session.waitUntilExit()
    let out = await session.stdout.string
    let err = await session.stderr.string
    let code: Int32
    switch state {
      case .succeeded: code = 0
      case .failed(let c): code = c
      default: code = -1
    }
    return (out, err, code)
  }

  func initGitRepo(at url: URL) async throws {
    let git = gitRunner(for: url)
    var r = await runGit(git, ["init"])
    XCTAssertEqual(r.code, 0, r.stderr)
    r = await runGit(git, ["config", "user.name", "Test User"])
    XCTAssertEqual(r.code, 0, r.stderr)
    r = await runGit(git, ["config", "user.email", "test@example.com"])
    XCTAssertEqual(r.code, 0, r.stderr)
    r = await runGit(git, ["config", "commit.gpgsign", "false"])
    XCTAssertEqual(r.code, 0, r.stderr)
    r = await runGit(git, ["config", "tag.gpgSign", "false"])
    XCTAssertEqual(r.code, 0, r.stderr)
    try "initial".write(to: url.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
    r = await runGit(git, ["add", "."])
    XCTAssertEqual(r.code, 0, r.stderr)
    r = await runGit(git, ["commit", "-m", "initial"])
    XCTAssertEqual(r.code, 0, r.stderr)
    r = await runGit(git, ["rev-parse", "--verify", "HEAD"])
    XCTAssertEqual(r.code, 0, r.stderr)

    // Create a separate bare remote so that `git fetch --tags` always succeeds
    let remote = try makeTempDir()
    let gitBare = gitRunner(for: remote)
    var b = await runGit(gitBare, ["init", "--bare"])
    XCTAssertEqual(b.code, 0, b.stderr)
    b = await runGit(git, ["remote", "add", "origin", remote.path])
    XCTAssertEqual(b.code, 0, b.stderr)
    b = await runGit(git, ["push", "-u", "origin", "HEAD"])
    XCTAssertEqual(b.code, 0, b.stderr)
  }

  func commit(at url: URL, message: String = "update") async throws {
    let git = gitRunner(for: url)
    let p = url.appendingPathComponent("file.txt")
    try (UUID().uuidString).appendLine(to: p)
    let add = await runGit(git, ["add", "."]) 
    XCTAssertEqual(add.code, 0, add.stderr)
    let commit = await runGit(git, ["commit", "-m", message])
    XCTAssertEqual(commit.code, 0, commit.stderr)
  }

  func tag(at url: URL, name: String) async throws {
    let git = gitRunner(for: url)
    let t = await runGit(git, ["tag", name])
    XCTAssertEqual(t.code, 0, t.stderr)
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

  func parser(platform: String, adopt: Bool, incrementTag: Bool) throws -> OptionParser {
    return OptionParser(testingPlatform: platform, incrementBuildTag: incrementTag, adoptOtherPlatformBuild: adopt)
  }

  func parser(platform: String, adopt: Bool, incrementTag: Bool, offset: UInt) throws -> OptionParser {
    return OptionParser(testingPlatform: platform, incrementBuildTag: incrementTag, adoptOtherPlatformBuild: adopt, buildOffset: offset)
  }

  // MARK: - Tests

  func testAdoptsBuildFromOtherPlatformTagAtHEAD() async throws {
    let repo = try makeTempDir()
    try await initGitRepo(at: repo)
    try await tag(at: repo, name: "v1.2.3-42-iOS")

    // Sanity: HEAD should resolve and tag should point at it
    let gitSanity = gitRunner(for: repo)
    let head = await runGit(gitSanity, ["rev-parse", "--verify", "HEAD"])
    XCTAssertEqual(head.code, 0, head.stderr)
    let pts = await runGit(gitSanity, ["tag", "--points-at", "HEAD"])
    XCTAssertTrue(pts.stdout.contains("v1.2.3-42-iOS"))

    let git = gitRunner(for: repo)
    let parsed = try parser(platform: "macOS", adopt: true, incrementTag: false)
    let (build, _) = try await parsed.nextBuildNumberAndCommit(in: repo, using: git)
    XCTAssertEqual(build, "42")
  }

  func testAdoptChoosesHighestBuildAcrossOtherPlatformsAtHEAD() async throws {
    let repo = try makeTempDir()
    try await initGitRepo(at: repo)
    try await tag(at: repo, name: "v1.2.3-10-iOS")
    try await tag(at: repo, name: "v2.0-99-tvOS")
    try await tag(at: repo, name: "v2.0-77-macCatalyst")

    // Sanity
    let gitSanity = gitRunner(for: repo)
    let head = await runGit(gitSanity, ["rev-parse", "--verify", "HEAD"])
    XCTAssertEqual(head.code, 0, head.stderr)
    let pts = await runGit(gitSanity, ["tag", "--points-at", "HEAD"])
    XCTAssertTrue(pts.stdout.contains("v2.0-99-tvOS"))

    let git = gitRunner(for: repo)
    let parsed = try parser(platform: "macOS", adopt: true, incrementTag: false)
    let (build, _) = try await parsed.nextBuildNumberAndCommit(in: repo, using: git)
    XCTAssertEqual(build, "99")
  }

  func testNoAdoptionFallsBackToIncrementTag() async throws {
    let repo = try makeTempDir()
    try await initGitRepo(at: repo)
    // add some unrelated platform tags at other commits
    try await tag(at: repo, name: "v1.0-5-macOS")
    try await commit(at: repo, message: "work")
    try await tag(at: repo, name: "v1.1-11-macOS")

    // sanity: tag list should include the macOS tag
    let sanityGit = gitRunner(for: repo)
    let tagsList = await runGit(sanityGit, ["tag"])
    XCTAssertEqual(tagsList.code, 0, tagsList.stderr)
    XCTAssertTrue(tagsList.stdout.contains("v1.1-11-macOS"))

    let git = gitRunner(for: repo)
    let parsed = try parser(platform: "macOS", adopt: true, incrementTag: true)
    let (build, _) = try await parsed.nextBuildNumberAndCommit(in: repo, using: git)
    // highest existing macOS tag is 11, so next should be 12
    XCTAssertEqual(build, "12")
  }

  func testNoAdoptionFallsBackToCommitCount() async throws {
    let repo = try makeTempDir()
    try await initGitRepo(at: repo)
    try await commit(at: repo, message: "second")

    let git = gitRunner(for: repo)
    let parsed = try parser(platform: "macOS", adopt: true, incrementTag: false)
    let (build, _) = try await parsed.nextBuildNumberAndCommit(in: repo, using: git)
    // we made two commits total
    XCTAssertEqual(build, "2")
  }

  func testAdoptPrefersOtherPlatformEvenIfSamePlatformTagAtHEAD() async throws {
    let repo = try makeTempDir()
    try await initGitRepo(at: repo)
    // Create both other-platform and same-platform tags at HEAD
    try await tag(at: repo, name: "v1.2.3-40-macOS")
    try await tag(at: repo, name: "v1.2.3-42-iOS")

    // sanity
    let gitSanity = gitRunner(for: repo)
    let pts = await runGit(gitSanity, ["tag", "--points-at", "HEAD"])
    XCTAssertTrue(pts.stdout.contains("v1.2.3-40-macOS"))
    XCTAssertTrue(pts.stdout.contains("v1.2.3-42-iOS"))

    let git = gitRunner(for: repo)
    let parsed = try parser(platform: "macOS", adopt: true, incrementTag: true)
    let (build, _) = try await parsed.nextBuildNumberAndCommit(in: repo, using: git)
    // should adopt 42 from iOS even though macOS tag also exists at HEAD
    XCTAssertEqual(build, "42")
  }

  func testAdoptionIgnoresBuildOffset() async throws {
    let repo = try makeTempDir()
    try await initGitRepo(at: repo)
    try await tag(at: repo, name: "v3.4.5-42-iOS")

    let git = gitRunner(for: repo)
    let parsed = try parser(platform: "macOS", adopt: true, incrementTag: true, offset: 100)
    let (build, _) = try await parsed.nextBuildNumberAndCommit(in: repo, using: git)
    // offset is ignored when adopting; should not be 142
    XCTAssertEqual(build, "42")
  }

  func testIncrementTagIgnoresOtherPlatformTagsAtHEAD() async throws {
    let repo = try makeTempDir()
    try await initGitRepo(at: repo)

    // Highest macOS tag on an earlier commit (not at HEAD)
    try await tag(at: repo, name: "v1.1-11-macOS")
    try await commit(at: repo, message: "advance HEAD")

    // At HEAD: create an other-platform tag and a lower macOS tag
    try await tag(at: repo, name: "v2.0-99-iOS")
    try await tag(at: repo, name: "v1.0-2-macOS")

    // Sanity: tags at HEAD should include these
    let sanity = gitRunner(for: repo)
    let pts = await runGit(sanity, ["tag", "--points-at", "HEAD"])
    XCTAssertTrue(pts.stdout.contains("v2.0-99-iOS"))
    XCTAssertTrue(pts.stdout.contains("v1.0-2-macOS"))

    // When adoption is disabled and incrementTag is enabled, we should
    // pick max macOS build (11) globally and add 1 => 12.
    let git = gitRunner(for: repo)
    let parsed = try parser(platform: "macOS", adopt: false, incrementTag: true)
    let (build, _) = try await parsed.nextBuildNumberAndCommit(in: repo, using: git)
    XCTAssertEqual(build, "12")
  }
}

extension String {
  fileprivate func appendLine(to url: URL) throws {
    let data = (self + "\n").data(using: .utf8)!
    if FileManager.default.fileExists(atPath: url.path) {
      let handle = try FileHandle(forWritingTo: url)
      try handle.seekToEnd()
      try handle.write(contentsOf: data)
      try handle.close()
    } else {
      try data.write(to: url)
    }
  }
}
