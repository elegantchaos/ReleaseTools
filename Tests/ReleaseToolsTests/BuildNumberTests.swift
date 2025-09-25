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

  @Test func adoptsBuildFromOtherPlatformTagAtHEAD() async throws {
    let repo = try makeTempDir()
    try await initGitRepo(at: repo)
    try await tag(at: repo, name: "v1.2.3-42-iOS")

    // Sanity: HEAD should resolve and tag should point at it
    let gitSanity = gitRunner(for: repo)
    let head = await runGit(gitSanity, ["rev-parse", "--verify", "HEAD"])
    #expect(head.state == .succeeded, Comment(rawValue: head.stderr))
    let pts = await runGit(gitSanity, ["tag", "--points-at", "HEAD"])
    #expect(pts.stdout.contains("v1.2.3-42-iOS"))

    let git = gitRunner(for: repo)
    let parsed = OptionParser(testingPlatform: "macOS", incrementBuildTag: false, adoptOtherPlatformBuild: true)
    let (build, _) = try await parsed.nextBuildNumberAndCommit(in: repo, using: git)
    #expect(build == "42")
  }

  @Test func adoptChoosesHighestBuildAcrossOtherPlatformsAtHEAD() async throws {
    let repo = try makeTempDir()
    print(repo.path)
    try await initGitRepo(at: repo)
    try await tag(at: repo, name: "v1.2.3-10-iOS")
    try await tag(at: repo, name: "v2.0-99-tvOS")
    try await tag(at: repo, name: "v2.0-77-macCatalyst")

    // Sanity
    let gitSanity = gitRunner(for: repo)
    let head = await runGit(gitSanity, ["rev-parse", "--verify", "HEAD"])
    #expect(head.state == .succeeded, Comment(rawValue: head.stderr))
    let pts = await runGit(gitSanity, ["tag", "--points-at", "HEAD"])
    #expect(pts.stdout.contains("v2.0-99-tvOS"))

    let git = gitRunner(for: repo)
    // useExistingTag now implies incrementBuildTag, so incrementTag parameter is ignored
    let parsed = OptionParser(testingPlatform: "macOS", incrementBuildTag: false, adoptOtherPlatformBuild: true)
    let (build, _) = try await parsed.nextBuildNumberAndCommit(in: repo, using: git)
    #expect(build == "99")
  }

  @Test func adoptionFallsBackToIncrementTag() async throws {
    let repo = try makeTempDir()
    try await initGitRepo(at: repo)

    // Create some older tags globally, but not at HEAD
    try await tag(at: repo, name: "v1.0-5-macOS")
    try await tag(at: repo, name: "v1.0-10-iOS")
    try await commit(at: repo, message: "second commit")
    try await tag(at: repo, name: "v1.5-11-macOS")
    try await commit(at: repo, message: "third commit (HEAD)")

    // When no adoption happens at HEAD, fall back to incrementTag.
    // The highest macOS build is 11, so we should get 12.
    let git = gitRunner(for: repo)
    let parsed = OptionParser(testingPlatform: "macOS", incrementBuildTag: true, adoptOtherPlatformBuild: true)
    let (build, _) = try await parsed.nextBuildNumberAndCommit(in: repo, using: git)
    #expect(build == "12")
  }

  @Test func useExistingTagFallsBackToIncrementTag() async throws {
    let repo = try makeTempDir()
    try await initGitRepo(at: repo)
    try await commit(at: repo, message: "second")

    let git = gitRunner(for: repo)
    // useExistingTag now implies incrementBuildTag, so it falls back to incrementTag (not commit count)
    let parsed = OptionParser(testingPlatform: "macOS", incrementBuildTag: false, adoptOtherPlatformBuild: true)
    let (build, _) = try await parsed.nextBuildNumberAndCommit(in: repo, using: git)
    // no existing tags for macOS, so incrementTag returns 1
    #expect(build == "1")
  }

  @Test func commitCountFallback() async throws {
    let repo = try makeTempDir()
    try await initGitRepo(at: repo)
    try await commit(at: repo, message: "second")

    let git = gitRunner(for: repo)
    // with adopt: false and incrementTag: false, should use commit count
    let parsed = OptionParser(testingPlatform: "macOS", incrementBuildTag: false, adoptOtherPlatformBuild: false)
    let (build, _) = try await parsed.nextBuildNumberAndCommit(in: repo, using: git)
    // we made two commits total
    #expect(build == "2")
  }

  @Test func useExistingTagImpliesIncrementTag() async throws {
    // This test verifies that useExistingTag automatically enables incrementBuildTag
    let parsed = OptionParser(testingPlatform: "macOS", incrementBuildTag: false, adoptOtherPlatformBuild: true)

    // Even though we passed incrementTag: false, useExistingTag should have overridden it
    #expect(parsed.useExistingTag, "useExistingTag should be true")
    #expect(parsed.incrementBuildTag, "incrementBuildTag should be true due to useExistingTag implication")

    // Test the opposite case for comparison (explicitly disable useExistingTag)
    let parsedNoAdopt = OptionParser(testingPlatform: "macOS", incrementBuildTag: false, adoptOtherPlatformBuild: false)
    #expect(!parsedNoAdopt.useExistingTag, "useExistingTag should be false when explicitly disabled")
    #expect(!parsedNoAdopt.incrementBuildTag, "incrementBuildTag should be false")
  }

  @Test func adoptPrefersOtherPlatformEvenIfSamePlatformTagAtHEAD() async throws {
    let repo = try makeTempDir()
    try await initGitRepo(at: repo)
    // Create both other-platform and same-platform tags at HEAD
    try await tag(at: repo, name: "v1.2.3-40-macOS")
    try await tag(at: repo, name: "v1.2.3-42-iOS")

    // sanity
    let gitSanity = gitRunner(for: repo)
    let pts = await runGit(gitSanity, ["tag", "--points-at", "HEAD"])
    #expect(pts.stdout.contains("v1.2.3-40-macOS"), "Expected v1.2.3-40-macOS in tags at HEAD: \(pts.stdout)")
    #expect(pts.stdout.contains("v1.2.3-42-iOS"), "Expected v1.2.3-42-iOS in tags at HEAD: \(pts.stdout)")

    let git = gitRunner(for: repo)
    let parsed = OptionParser(testingPlatform: "macOS", incrementBuildTag: true, adoptOtherPlatformBuild: true)
    let (build, _) = try await parsed.nextBuildNumberAndCommit(in: repo, using: git)
    // should adopt 42 from iOS even though macOS tag also exists at HEAD
    #expect(build == "42")
  }

  @Test func adoptionIgnoresBuildOffset() async throws {
    let repo = try makeTempDir()
    try await initGitRepo(at: repo)
    try await tag(at: repo, name: "v3.4.5-42-iOS")

    let git = gitRunner(for: repo)
    let parsed = OptionParser(testingPlatform: "macOS", incrementBuildTag: true, adoptOtherPlatformBuild: true, buildOffset: 100)
    let (build, _) = try await parsed.nextBuildNumberAndCommit(in: repo, using: git)
    // offset is ignored when adopting; should not be 142
    #expect(build == "42")
  }

  @Test func incrementTagIgnoresOtherPlatformTagsAtHEAD() async throws {
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
    #expect(pts.stdout.contains("v2.0-99-iOS"), "Expected v2.0-99-iOS in tags at HEAD: \(pts.stdout)")
    #expect(pts.stdout.contains("v1.0-2-macOS"), "Expected v1.0-2-macOS in tags at HEAD: \(pts.stdout)")

    // When adoption is disabled and incrementTag is enabled, we should
    // pick max macOS build (11) globally and add 1 => 12.
    let git = gitRunner(for: repo)
    let parsed = OptionParser(testingPlatform: "macOS", incrementBuildTag: true, adoptOtherPlatformBuild: false)
    let (build, _) = try await parsed.nextBuildNumberAndCommit(in: repo, using: git)
    #expect(build == "12")
  }

  @Test func explicitBuildUsesSpecifiedNumber() async throws {
    let repo = try makeTempDir()
    try await initGitRepo(at: repo)

    let git = gitRunner(for: repo)
    let parsed = OptionParser(testingPlatform: "macOS", incrementBuildTag: false, adoptOtherPlatformBuild: false, explicitBuild: "42")
    let (build, _) = try await parsed.nextBuildNumberAndCommit(in: repo, using: git)
    #expect(build == "42")
  }

  @Test func explicitBuildIgnoresExistingTags() async throws {
    let repo = try makeTempDir()
    try await initGitRepo(at: repo)
    try await tag(at: repo, name: "v1.0-100-macOS")
    try await tag(at: repo, name: "v1.0-200-iOS")

    let git = gitRunner(for: repo)
    let parsed = OptionParser(testingPlatform: "macOS", incrementBuildTag: false, adoptOtherPlatformBuild: false, explicitBuild: "5")
    let (build, _) = try await parsed.nextBuildNumberAndCommit(in: repo, using: git)
    #expect(build == "5")
  }

  @Test func explicitBuildRejectsInvalidNumbers() async throws {
    let repo = try makeTempDir()
    try await initGitRepo(at: repo)

    let git = gitRunner(for: repo)
    let parsed = OptionParser(testingPlatform: "macOS", incrementBuildTag: false, adoptOtherPlatformBuild: false, explicitBuild: "not-a-number")

    do {
      let _ = try await parsed.nextBuildNumberAndCommit(in: repo, using: git)
      #expect(Bool(false), "Should have thrown UpdateBuildError.invalidExplicitBuild")
    } catch let error as UpdateBuildError {
      switch error {
        case .invalidExplicitBuild:
          #expect(true)
        default:
          #expect(Bool(false), "Should throw UpdateBuildError.invalidExplicitBuild for invalid number, got: \(error)")
      }
    } catch {
      #expect(Bool(false), "Should throw UpdateBuildError.invalidExplicitBuild for invalid number, got: \(error)")
    }
  }
}
