// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 19/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Files
import Foundation
import Resources
import Runner

enum UpdateBuildError: Error {
  case gettingBuildFailed(_ result: Runner.Result)
  case gettingCommitFailed(_ result: Runner.Result)
  case writingConfigFailed
  case updatingIndexFailed(_ result: Runner.Result)

  public var description: String {
    switch self {
    case .gettingBuildFailed(let result):
      return "Failed to get the build number from git.\n\(result)"
    case .gettingCommitFailed(let result): return "Failed to get the commit from git.\n\(result)"
    case .writingConfigFailed: return "Failed to write the config file."
    case .updatingIndexFailed(let result):
      return "Failed to tell git to ignore the config file.\n\(result)"
    }
  }
}

struct UpdateBuildCommand: ParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "update-build",
    abstract: "Update an .xcconfig file to contain the latest build number."
  )

  @Option(help: "The .xcconfig file to update.") var config: String?
  @Option(help: "The header file to generate.") var header: String?
  @Option(help: "The .plist file to update.") var plist: String?
  @Option(help: "The .plist file to update.") var plistDest: String?
  @Option(help: "The git repo to derive the build number from.") var repo: String?

  @OptionGroup() var options: CommonOptions

  func run() throws {
    let parsed = try OptionParser(
      options: options,
      command: Self.configuration
    )

    if let header = header, let repo = repo {
      try Self.generateHeader(parsed: parsed, header: header, repo: repo)
    } else if let plist = plist, let dest = plistDest, let repo = repo {
      try Self.generatePlist(parsed: parsed, source: plist, dest: dest, repo: repo)
    } else {
      try Self.generateConfig(parsed: parsed, config: config)
    }
  }

  static func getBuild(in url: URL, using git: GitRunner) throws -> (String, String) {
    git.cwd = url
    chdir(url.path)

    var result = try git.sync(arguments: ["rev-list", "--count", "HEAD"])
    if result.status != 0 {
      throw UpdateBuildError.gettingBuildFailed(result)
    }

    let build = result.stdout.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

    result = try git.sync(arguments: ["rev-list", "--max-count", "1", "HEAD"])
    if result.status != 0 {
      throw UpdateBuildError.gettingCommitFailed(result)
    }

    let commit = result.stdout.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

    return (build, commit)
  }

  static func generatePlist(parsed: OptionParser, source: String, dest: String, repo: String) throws
  {
    let plistURL = URL(fileURLWithPath: source)
    let destURL = URL(fileURLWithPath: dest)
    let repoURL = URL(fileURLWithPath: repo)
    let data = try Data(contentsOf: plistURL)
    let info = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)

    let git = GitRunner()
    let (build, commit) = try getBuild(in: repoURL, using: git)

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

  static func generateHeader(parsed: OptionParser, header: String, repo: String) throws -> String {
    let headerURL = URL(fileURLWithPath: header)
    let repoURL = URL(fileURLWithPath: repo)

    let git = GitRunner()
    let (build, commit) = try getBuild(in: repoURL, using: git)
    parsed.log("Setting build number to \(build).")
    let header =
      "#define BUILD \(build)\n#define CURRENT_PROJECT_VERSION \(build)\n#define COMMIT \(commit)"
    try? FileManager.default.createDirectory(
      at: headerURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try header.write(to: headerURL, atomically: true, encoding: .utf8)
    return build
  }

  static func generateConfig(parsed: OptionParser, config: String?) throws {

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
    let (build, commit) = try getBuild(in: configURL.deletingLastPathComponent(), using: git)
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

      let result = try git.sync(arguments: ["update-index", "--assume-unchanged", configURL.path])
      if result.status != 0 {
        throw UpdateBuildError.updatingIndexFailed(result)
      }

    }
  }
}
