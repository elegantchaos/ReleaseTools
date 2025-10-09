// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 08/10/25.
//  All code (c) 2025 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Functionality for generating build-related files.
extension ReleaseEngine {
  /// Generate a header file containing the build number, commit hash, and version.
  func generateHeader(header: String, requireHEADTag: Bool) async throws -> BuildInfo {
    let headerURL = URL(fileURLWithPath: header)

    let buildInfo = try await buildInfoFromTag(requireHeadTag: requireHEADTag)
    log("Setting build number to \(buildInfo.build).")
    let header =
      "#define RT_BUILD \(buildInfo.build)\n#define RT_COMMIT \(buildInfo.commit)\n#define RT_VERSION \"\(buildInfo.version)\""
    try? FileManager.default.createDirectory(
      at: headerURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try header.write(to: headerURL, atomically: true, encoding: .utf8)
    log("Updated \(headerURL.lastPathComponent).")
    return buildInfo
  }

  /// Generate or update an xcconfig file containing the build number and commit hash.
  func generateConfig(config: String?) async throws {
    let configURL: URL
    if let config = config {
      configURL = URL(fileURLWithPath: config)
    } else if let sourceRoot = ProcessInfo.processInfo.environment["SOURCE_ROOT"] {
      configURL = URL(fileURLWithPath: sourceRoot).appendingPathComponent("Configs")
        .appendingPathComponent("BuildNumber.xcconfig")
    } else {
      configURL = URL(fileURLWithPath: "Configs/BuildNumber.xcconfig")
    }

    let buildInfo = try await buildInfoFromTag(requireHeadTag: false)
    let new = "RT_BUILD = \(buildInfo.build)\nRT_COMMIT = \(buildInfo.commit)\nRT_VERSION = \(buildInfo.version)"

    if let existing = try? String(contentsOf: configURL, encoding: .utf8), existing == new {
      log("Build number is \(buildInfo.build).")
    } else {
      log("Updating build number to \(buildInfo.build).")
      do {
        try new.write(to: configURL, atomically: true, encoding: .utf8)
        log("Updated \(configURL.lastPathComponent).")
      } catch {
        throw UpdateBuildError.writingConfigFailed(error.localizedDescription)
      }

      let result = git.run(["update-index", "--assume-unchanged", configURL.path])
      try await result.throwIfFailed(UpdateBuildError.updatingIndexFailed)
    }
  }

  /// Generate or update a plist file containing the build number and commit hash, and also generate a header file alongside it.
  func generatePlist(source: String, dest: String) async throws {
    let plistURL = URL(fileURLWithPath: source)
    let destURL = URL(fileURLWithPath: dest)
    let data = try Data(contentsOf: plistURL)
    let info = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)

    let buildInfo = try await buildInfoFromTag(requireHeadTag: false)

    if var info = info as? [String: Any] {
      if let existing = (info["CFBundleVersion"] as? String).map({ UInt($0) }), existing == buildInfo.build {
        log("Build number is \(buildInfo.build).")
      } else {
        log("Using build number \(buildInfo.build).")
        info["CFBundleVersion"] = buildInfo.build
        info["Commit"] = buildInfo.commit
        info["Version"] = buildInfo.version
        let data = try PropertyListSerialization.data(
          fromPropertyList: info, format: .xml, options: 0)
        try data.write(to: destURL, options: .atomic)
        log("Updated \(destURL.lastPathComponent).")

        let headerURL = destURL.deletingLastPathComponent().appendingPathComponent("RTInfo.h")
        let header = "#define RT_BUILD \(buildInfo.build)\n#define RT_COMMIT \(buildInfo.commit)\n#define RT_VERSION \"\(buildInfo.version)\""
        try header.write(to: headerURL, atomically: true, encoding: .utf8)
        log("Updated \(headerURL.lastPathComponent).")
      }
    }
  }
}
