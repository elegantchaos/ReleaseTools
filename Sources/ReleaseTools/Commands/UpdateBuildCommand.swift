// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 19/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import ChaosByteStreams
import Files
import Foundation
import Resources
import Runner

enum UpdateBuildError: RunnerError {
  case gettingBuildFailed
  case gettingCommitFailed
  case writingConfigFailed
  case updatingIndexFailed

  func description(for session: Runner.Session) async -> String {
    async let stderr = String(session.stderr)
    switch self {
      case .gettingBuildFailed: return "Failed to get the build number from git.\n\n\(await stderr)"
      case .gettingCommitFailed: return "Failed to get the commit from git.\n\n\(await stderr)"
      case .writingConfigFailed: return "Failed to write the config file.\n\n\(await stderr)"
      case .updatingIndexFailed: return "Failed to tell git to ignore the config file.\n\n\(await stderr)"
    }
  }
}

struct UpdateBuildCommand: AsyncParsableCommand {
  static var configuration: CommandConfiguration {
    CommandConfiguration(
      commandName: "update-build",
      abstract: "Update an .xcconfig file to contain the latest build number."
    )
  }

  @Option(help: "The .xcconfig file to update.") var config: String?
  @Option(help: "The header file to generate.") var header: String?
  @Option(help: "The .plist file to update.") var plist: String?
  @Option(help: "The .plist file to update.") var plistDest: String?
  @Option(help: "The git repo to derive the build number from.") var repo: String?

  @OptionGroup() var options: CommonOptions

  func run() async throws {
    let parsed = try OptionParser(
      options: options,
      command: Self.configuration
    )

    if let header = header, let repo = repo {
      _ = try await Self.generateHeader(parsed: parsed, header: header, repo: repo)
    } else if let plist = plist, let dest = plistDest, let repo = repo {
      try await Self.generatePlist(parsed: parsed, source: plist, dest: dest, repo: repo)
    } else {
      try await Self.generateConfig(parsed: parsed, config: config)
    }
  }

  static func getBuild(in url: URL, using git: GitRunner) async throws -> (String, String) {
    git.cwd = url
    chdir(url.path)

    var result = try git.run(["rev-list", "--count", "HEAD"])
    try await result.throwIfFailed(UpdateBuildError.gettingBuildFailed)

    let build = await String(result.stdout).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

    result = try git.run(["rev-list", "--max-count", "1", "HEAD"])
    try await result.throwIfFailed(UpdateBuildError.gettingCommitFailed)
    let commit = await String(result.stdout).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

    return (build, commit)
  }

  static func generatePlist(parsed: OptionParser, source: String, dest: String, repo: String) async throws {
    let plistURL = URL(fileURLWithPath: source)
    let destURL = URL(fileURLWithPath: dest)
    let repoURL = URL(fileURLWithPath: repo)
    let data = try Data(contentsOf: plistURL)
    let info = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)

    let git = GitRunner()
    let (build, commit) = try await getBuild(in: repoURL, using: git)

    if var info = info as? [String: Any] {
      print(info)
      if let existing = info["CFBundleVersion"] as? String, existing == build {
        parsed.log("Build number is \(build).")
      } else {
        parsed.log("Setting build number to \(build).")
        info["CFBundleVersion"] = build
        info["Commit"] = commit
        let data = try PropertyListSerialization.data(
          fromPropertyList: info, format: .xml, options: 0)
        try data.write(to: destURL, options: .atomic)

        let headerURL = destURL.deletingLastPathComponent().appendingPathComponent("RTInfo.h")
        let header = "#define BUILD \(build)\n#define COMMIT \(commit)"
        try header.write(to: headerURL, atomically: true, encoding: .utf8)
      }
    }
  }

  static func generateHeader(parsed: OptionParser, header: String, repo: String) async throws -> String {
    let headerURL = URL(fileURLWithPath: header)
    let repoURL = URL(fileURLWithPath: repo)

    let git = GitRunner()
    let (build, commit) = try await getBuild(in: repoURL, using: git)
    parsed.log("Setting build number to \(build).")
    let header =
      "#define BUILD \(build)\n#define CURRENT_PROJECT_VERSION \(build)\n#define COMMIT \(commit)"
    try? FileManager.default.createDirectory(
      at: headerURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try header.write(to: headerURL, atomically: true, encoding: .utf8)
    return build
  }

  static func generateConfig(parsed: OptionParser, config: String?) async throws {

    let configURL: URL
    if let config = config {
      configURL = URL(fileURLWithPath: config)
    } else if let sourceRoot = ProcessInfo.processInfo.environment["SOURCE_ROOT"] {
      configURL = URL(fileURLWithPath: sourceRoot).appendingPathComponent("Configs")
        .appendingPathComponent("BuildNumber.xcconfig")
    } else {
      configURL = URL(fileURLWithPath: "Configs/BuildNumber.xcconfig")
    }

    let git = GitRunner()
    let (build, commit) = try await getBuild(in: configURL.deletingLastPathComponent(), using: git)
    let new = "BUILD_NUMBER = \(build)\nBUILD_COMMIT = \(commit)"

    if let existing = try? String(contentsOf: configURL), existing == new {
      parsed.log("Build number is \(build).")
    } else {
      parsed.log("Updating build number to \(build).")
      do {
        try new.write(to: configURL, atomically: true, encoding: .utf8)
      } catch {
        throw UpdateBuildError.writingConfigFailed
      }

      let result = try git.run(["update-index", "--assume-unchanged", configURL.path])
      try await result.throwIfFailed(UpdateBuildError.updatingIndexFailed)
    }
  }
}
