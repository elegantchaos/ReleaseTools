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

  // Run a git command and assert it succeeded. Returns the same tuple as runGit.
  @discardableResult
  func XCTAssertGit(_ git: GitRunner, _ args: [String], file: StaticString = #filePath, line: UInt = #line) async -> (stdout: String, stderr: String, code: Int32) {
    let r = await runGit(git, args)
    XCTAssertEqual(r.code, 0, r.stderr, file: file, line: line)
    return r
  }

  func initGitRepo(at url: URL) async throws {
    let git = gitRunner(for: url)
    await XCTAssertGit(git, ["init"])
    await XCTAssertGit(git, ["config", "user.name", "Test User"])
    await XCTAssertGit(git, ["config", "user.email", "test@example.com"])
    await XCTAssertGit(git, ["config", "commit.gpgsign", "false"])
    await XCTAssertGit(git, ["config", "tag.gpgSign", "false"])
    try "initial".write(to: url.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
    await XCTAssertGit(git, ["add", "."])
    await XCTAssertGit(git, ["commit", "-m", "initial"])
    await XCTAssertGit(git, ["rev-parse", "--verify", "HEAD"])
  }

  func commit(at url: URL, message: String = "update") async throws {
    let git = gitRunner(for: url)
    let filename = "file-\(UUID().uuidString).txt"
    let p = url.appendingPathComponent(filename)
    try message.write(to: p, atomically: true, encoding: .utf8)
    await XCTAssertGit(git, ["add", "."])
    await XCTAssertGit(git, ["commit", "-m", message])
  }

  func tag(at url: URL, name: String) async throws {
    let git = gitRunner(for: url)
    await XCTAssertGit(git, ["tag", name])
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
    // useExistingTag now implies incrementBuildTag, so incrementTag parameter is ignored
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
    XCTAssertTrue(tagsList.stdout.contains("v1.1-11-macOS"), "Expected v1.1-11-macOS in tags: \(tagsList.stdout)")

    let git = gitRunner(for: repo)
    let parsed = try parser(platform: "macOS", adopt: true, incrementTag: true)
    let (build, _) = try await parsed.nextBuildNumberAndCommit(in: repo, using: git)
    // highest existing macOS tag is 11, so next should be 12
    XCTAssertEqual(build, "12")
  }

  func testUseExistingTagFallsBackToIncrementTag() async throws {
    let repo = try makeTempDir()
    try await initGitRepo(at: repo)
    try await commit(at: repo, message: "second")

    let git = gitRunner(for: repo)
    // useExistingTag now implies incrementBuildTag, so it falls back to incrementTag (not commit count)
    let parsed = try parser(platform: "macOS", adopt: true, incrementTag: false)
    let (build, _) = try await parsed.nextBuildNumberAndCommit(in: repo, using: git)
    // no existing tags for macOS, so incrementTag returns 1
    XCTAssertEqual(build, "1")
  }

  func testCommitCountFallback() async throws {
    let repo = try makeTempDir()
    try await initGitRepo(at: repo)
    try await commit(at: repo, message: "second")

    let git = gitRunner(for: repo)
    // with adopt: false and incrementTag: false, should use commit count
    let parsed = try parser(platform: "macOS", adopt: false, incrementTag: false)
    let (build, _) = try await parsed.nextBuildNumberAndCommit(in: repo, using: git)
    // we made two commits total
    XCTAssertEqual(build, "2")
  }

  func testUseExistingTagImpliesIncrementTag() async throws {
    // This test verifies that useExistingTag automatically enables incrementBuildTag
    let parsed = try parser(platform: "macOS", adopt: true, incrementTag: false)

    // Even though we passed incrementTag: false, useExistingTag should have overridden it
    XCTAssertTrue(parsed.useExistingTag, "useExistingTag should be true")
    XCTAssertTrue(parsed.incrementBuildTag, "incrementBuildTag should be true due to useExistingTag implication")

    // Test the opposite case for comparison
    let parsedNoAdopt = try parser(platform: "macOS", adopt: false, incrementTag: false)
    XCTAssertFalse(parsedNoAdopt.useExistingTag, "useExistingTag should be false")
    XCTAssertFalse(parsedNoAdopt.incrementBuildTag, "incrementBuildTag should be false")
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
    XCTAssertTrue(pts.stdout.contains("v1.2.3-40-macOS"), "Expected v1.2.3-40-macOS in tags at HEAD: \(pts.stdout)")
    XCTAssertTrue(pts.stdout.contains("v1.2.3-42-iOS"), "Expected v1.2.3-42-iOS in tags at HEAD: \(pts.stdout)")

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
    XCTAssertTrue(pts.stdout.contains("v2.0-99-iOS"), "Expected v2.0-99-iOS in tags at HEAD: \(pts.stdout)")
    XCTAssertTrue(pts.stdout.contains("v1.0-2-macOS"), "Expected v1.0-2-macOS in tags at HEAD: \(pts.stdout)")

    // When adoption is disabled and incrementTag is enabled, we should
    // pick max macOS build (11) globally and add 1 => 12.
    let git = gitRunner(for: repo)
    let parsed = try parser(platform: "macOS", adopt: false, incrementTag: true)
    let (build, _) = try await parsed.nextBuildNumberAndCommit(in: repo, using: git)
    XCTAssertEqual(build, "12")
  }
}
