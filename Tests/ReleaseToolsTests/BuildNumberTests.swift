// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Tests on 24/09/25.
//  All code (c) 2025 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import XCTest
import ArgumentParser
@testable import ReleaseTools

final class BuildNumberTests: XCTestCase {

  // MARK: - Helpers

  func makeTempDir() throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("ReleaseToolsTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  @discardableResult
  func sh(_ args: [String], cwd: URL) throws -> (stdout: String, stderr: String, code: Int32) {
    let task = Process()
    task.currentDirectoryURL = cwd
    task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    task.arguments = args

    let out = Pipe(); task.standardOutput = out
    let err = Pipe(); task.standardError = err
    try task.run()
    task.waitUntilExit()

    let dataOut = out.fileHandleForReading.readDataToEndOfFile()
    let dataErr = err.fileHandleForReading.readDataToEndOfFile()
    return (
      String(decoding: dataOut, as: UTF8.self),
      String(decoding: dataErr, as: UTF8.self),
      task.terminationStatus
    )
  }

  func initGitRepo(at url: URL) throws {
    let r0 = try sh(["git", "init"], cwd: url); XCTAssertEqual(r0.code, 0, r0.stderr)
  let r1 = try sh(["git", "config", "user.name", "Test User"], cwd: url); XCTAssertEqual(r1.code, 0, r1.stderr)
  let r2 = try sh(["git", "config", "user.email", "test@example.com"], cwd: url); XCTAssertEqual(r2.code, 0, r2.stderr)
  let r1b = try sh(["git", "config", "commit.gpgsign", "false"], cwd: url); XCTAssertEqual(r1b.code, 0, r1b.stderr)
  let r1c = try sh(["git", "config", "tag.gpgSign", "false"], cwd: url); XCTAssertEqual(r1c.code, 0, r1c.stderr)
    try "initial".write(to: url.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
    let r3 = try sh(["git", "add", "."], cwd: url); XCTAssertEqual(r3.code, 0, r3.stderr)
    let r4 = try sh(["git", "commit", "-m", "initial"], cwd: url); XCTAssertEqual(r4.code, 0, r4.stderr)
    let r5 = try sh(["git","rev-parse","--verify","HEAD"], cwd: url); XCTAssertEqual(r5.code, 0, r5.stderr)

    // Create a separate bare remote so that `git fetch --tags` always succeeds
    let remote = try makeTempDir()
    let b0 = try sh(["git", "init", "--bare"], cwd: remote); XCTAssertEqual(b0.code, 0, b0.stderr)
    let b1 = try sh(["git", "remote", "add", "origin", remote.path], cwd: url); XCTAssertEqual(b1.code, 0, b1.stderr)
    let b2 = try sh(["git", "push", "-u", "origin", "HEAD"], cwd: url); XCTAssertEqual(b2.code, 0, b2.stderr)
  }

  func commit(at url: URL, message: String = "update") throws {
    let p = url.appendingPathComponent("file.txt")
    try (UUID().uuidString).appendLine(to: p)
    _ = try sh(["git", "add", "."], cwd: url)
    _ = try sh(["git", "commit", "-m", message], cwd: url)
  }

  func tag(at url: URL, name: String) throws {
    _ = try sh(["git", "tag", name], cwd: url)
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

  // MARK: - Tests

  func testAdoptsBuildFromOtherPlatformTagAtHEAD() async throws {
    let repo = try makeTempDir()
    try initGitRepo(at: repo)
    try tag(at: repo, name: "v1.2.3-42-iOS")

    // Sanity: HEAD should resolve and tag should point at it
    let head = try sh(["git","rev-parse","--verify","HEAD"], cwd: repo)
    XCTAssertEqual(head.code, 0, head.stderr)
    let pts = try sh(["git","tag","--points-at","HEAD"], cwd: repo)
    XCTAssertTrue(pts.stdout.contains("v1.2.3-42-iOS"))

    let git = gitRunner(for: repo)
    let parsed = try parser(platform: "macOS", adopt: true, incrementTag: false)
  let (build, _) = try await parsed.nextBuildNumberAndCommit(in: repo, using: git)
    XCTAssertEqual(build, "42")
  }

  func testAdoptChoosesHighestBuildAcrossOtherPlatformsAtHEAD() async throws {
    let repo = try makeTempDir()
    try initGitRepo(at: repo)
    try tag(at: repo, name: "v1.2.3-10-iOS")
    try tag(at: repo, name: "v2.0-99-tvOS")
    try tag(at: repo, name: "v2.0-77-macCatalyst")

    // Sanity
    let head = try sh(["git","rev-parse","--verify","HEAD"], cwd: repo)
    XCTAssertEqual(head.code, 0, head.stderr)
    let pts = try sh(["git","tag","--points-at","HEAD"], cwd: repo)
    XCTAssertTrue(pts.stdout.contains("v2.0-99-tvOS"))

    let git = gitRunner(for: repo)
    let parsed = try parser(platform: "macOS", adopt: true, incrementTag: false)
  let (build, _) = try await parsed.nextBuildNumberAndCommit(in: repo, using: git)
    XCTAssertEqual(build, "99")
  }

  func testNoAdoptionFallsBackToIncrementTag() async throws {
    let repo = try makeTempDir()
    try initGitRepo(at: repo)
    // add some unrelated platform tags at other commits
    try tag(at: repo, name: "v1.0-5-macOS")
    try commit(at: repo, message: "work")
    try tag(at: repo, name: "v1.1-11-macOS")

    let git = gitRunner(for: repo)
    let parsed = try parser(platform: "macOS", adopt: true, incrementTag: true)
  let (build, _) = try await parsed.nextBuildNumberAndCommit(in: repo, using: git)
    // highest existing macOS tag is 11, so next should be 12
    XCTAssertEqual(build, "12")
  }

  func testNoAdoptionFallsBackToCommitCount() async throws {
    let repo = try makeTempDir()
    try initGitRepo(at: repo)
    try commit(at: repo, message: "second")

    let git = gitRunner(for: repo)
    let parsed = try parser(platform: "macOS", adopt: true, incrementTag: false)
  let (build, _) = try await parsed.nextBuildNumberAndCommit(in: repo, using: git)
    // we made two commits total
    XCTAssertEqual(build, "2")
  }
}

private extension String {
  func appendLine(to url: URL) throws {
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
