// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 08/10/25.
//  All code (c) 2025 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Functionality for generating build-related files.
struct Generation {
  /// Generate a header file containing the build number and commit hash.
  static func generateHeader(parsed: OptionParser, header: String, requireHEADTag: Bool) async throws -> (UInt, String) {
    let headerURL = URL(fileURLWithPath: header)

    let (build, commit) = try await parsed.buildNumberAndCommit(requireHeadTag: requireHEADTag)
    parsed.log("Setting build number to \(build).")
    let header =
      "#define CURRENT_PROJECT_VERSION \(build)\n#define CURRENT_PROJECT_COMMIT \(commit)"
    try? FileManager.default.createDirectory(
      at: headerURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try header.write(to: headerURL, atomically: true, encoding: .utf8)
    parsed.log("Updated \(headerURL.lastPathComponent).")
    return (build, commit)
  }

  /// Generate or update an xcconfig file containing the build number and commit hash.
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

    let (build, commit) = try await parsed.buildNumberAndCommit(requireHeadTag: false)
    let new = "CURRENT_PROJECT_VERSION = \(build)\nCURRENT_PROJECT_COMMIT = \(commit)"

    if let existing = try? String(contentsOf: configURL, encoding: .utf8), existing == new {
      parsed.log("Build number is \(build).")
    } else {
      parsed.log("Updating build number to \(build).")
      do {
        try new.write(to: configURL, atomically: true, encoding: .utf8)
        parsed.log("Updated \(configURL.lastPathComponent).")
      } catch {
        throw UpdateBuildError.writingConfigFailed(error.localizedDescription)
      }

      let result = parsed.git.run(["update-index", "--assume-unchanged", configURL.path])
      try await result.throwIfFailed(UpdateBuildError.updatingIndexFailed)
    }
  }

  /// Generate or update a plist file containing the build number and commit hash, and also generate a header file alongside it.
  static func generatePlist(parsed: OptionParser, source: String, dest: String) async throws {
    let plistURL = URL(fileURLWithPath: source)
    let destURL = URL(fileURLWithPath: dest)
    let data = try Data(contentsOf: plistURL)
    let info = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)

    let (build, commit) = try await parsed.buildNumberAndCommit(requireHeadTag: false)

    if var info = info as? [String: Any] {
      if let existing = (info["CFBundleVersion"] as? String).map({ UInt($0) }), existing == build {
        parsed.log("Build number is \(build).")
      } else {
        parsed.log("Using build number \(build).")
        info["CFBundleVersion"] = build
        info["Commit"] = commit
        let data = try PropertyListSerialization.data(
          fromPropertyList: info, format: .xml, options: 0)
        try data.write(to: destURL, options: .atomic)
        parsed.log("Updated \(destURL.lastPathComponent).")

        let headerURL = destURL.deletingLastPathComponent().appendingPathComponent("RTInfo.h")
        let header = "#define CURRENT_PROJECT_VERSION \(build)\n#define CURRENT_PROJECT_COMMIT \(commit)"
        try header.write(to: headerURL, atomically: true, encoding: .utf8)
        parsed.log("Updated \(headerURL.lastPathComponent).")
      }
    }
  }
}
