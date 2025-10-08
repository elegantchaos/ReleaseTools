// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 08/10/25.
//  All code (c) 2025 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Runner

enum TagError: Runner.Error {
  case tagAlreadyExists(String)
  case gettingVersionFailed
  case gettingBuildFailed
  case creatingTagFailed
  case noVersionFound

  func description(for session: Runner.Session) async -> String {
    async let stderr = session.stderr.string
    switch self {
      case .tagAlreadyExists(let tag):
        return "A version tag already exists at HEAD: \(tag)"
      case .gettingVersionFailed:
        return "Failed to get the version information.\n\n\(await stderr)"
      case .gettingBuildFailed:
        return "Failed to calculate the build number.\n\n\(await stderr)"
      case .creatingTagFailed:
        return "Failed to create the git tag.\n\n\(await stderr)"
      case .noVersionFound:
        return "Could not determine the version. Please ensure your project has a MARKETING_VERSION or CFBundleShortVersionString set."
    }
  }
}

struct TagCommand: AsyncParsableCommand {
  static var configuration: CommandConfiguration {
    CommandConfiguration(
      commandName: "tag",
      abstract: "Create a version tag at HEAD if one doesn't exist."
    )
  }

  @Option(help: "The version to use for the tag (e.g., 1.2.3). If not specified, will try to determine from project files.") var tagVersion: String?
  @Option(help: "Explicit build number to use for the tag.") var explicitBuild: String?

  @OptionGroup() var options: CommonOptions

  func run() async throws {
    let parsed = try OptionParser(
      options: options,
      command: Self.configuration
    )

    let git = GitRunner()

    // Check if there's already a version tag at HEAD
    try await ensureNoExistingTag(using: git, parsed: parsed)

    // Get or determine the version
    let version = try await getVersion(using: git, parsed: parsed, repoURL: parsed.rootURL)

    // Get the build number (either explicit or calculated)
    let build: UInt
    if let explicitBuild {
      guard let explicitBuildNumber = UInt(explicitBuild) else {
        throw UpdateBuildError.invalidExplicitBuild(explicitBuild)
      }
      parsed.verbose("Using explicit build number: \(explicitBuildNumber)")
      build = explicitBuildNumber
    } else {
      // Calculate the build number (platform-agnostic)
      build = try await parsed.nextPlatformAgnosticBuildNumber(using: git)
    }

    // Get current commit
    let commitResult = git.run(["rev-list", "--max-count", "1", "HEAD"])
    try await commitResult.throwIfFailed(TagError.gettingBuildFailed)
    let commit = await commitResult.stdout.string.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

    // Create the tag in format: v<version>-<build>
    let tagName = "v\(version)-\(build)"

    parsed.log("Creating tag: \(tagName) at commit \(commit)")

    let tagResult = git.run(["tag", tagName, commit])
    try await tagResult.throwIfFailed(TagError.creatingTagFailed)

    parsed.log("Successfully created tag: \(tagName)")
  }

  /// Check if there's already a version tag at HEAD and throw an error if found
  private func ensureNoExistingTag(using git: GitRunner, parsed: OptionParser) async throws {
    // Get tags pointing at HEAD
    let result = git.run(["tag", "--points-at", "HEAD"])
    let state = await result.waitUntilExit()

    guard case .succeeded = state else {
      // If we can't check tags, continue anyway
      return
    }

    let pattern = #/^v\d+\.\d+(\.\d+)*-\d+$/#

    for await line in await result.stdout.lines {
      let tag = line.trimmingCharacters(in: .whitespacesAndNewlines)
      if tag.firstMatch(of: pattern) != nil {
        throw TagError.tagAlreadyExists(tag)
      }
    }
  }

  /// Get the version string, either from the --version option or by detecting it from project files
  private func getVersion(using git: GitRunner, parsed: OptionParser, repoURL: URL) async throws -> String {
    if let tagVersion = tagVersion {
      return tagVersion
    }

    // Try to find version from common project files
    // Look for .xcodeproj or Package.swift
    let fm = FileManager.default

    // Try to find an Info.plist or xcconfig file with version info
    if let version = try? findVersionInDirectory(repoURL, fileManager: fm) {
      parsed.verbose("Found version: \(version)")
      return version
    }

    throw TagError.noVersionFound
  }

  /// Search for version information in project files
  private func findVersionInDirectory(_ url: URL, fileManager: FileManager) throws -> String? {
    // Look for xcconfig files
    if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
      for case let fileURL as URL in enumerator {
        let filename = fileURL.lastPathComponent

        // Check xcconfig files
        if filename.hasSuffix(".xcconfig") {
          if let version = try? extractVersionFromXCConfig(fileURL) {
            return version
          }
        }

        // Check Info.plist files
        if filename == "Info.plist" {
          if let version = try? extractVersionFromPlist(fileURL) {
            return version
          }
        }
      }
    }

    return nil
  }

  /// Extract version from an xcconfig file
  private func extractVersionFromXCConfig(_ url: URL) throws -> String? {
    let content = try String(contentsOf: url, encoding: .utf8)
    let pattern = #/MARKETING_VERSION\s*=\s*([^\s;]+)/#

    if let match = content.firstMatch(of: pattern) {
      return String(match.1)
    }

    return nil
  }

  /// Extract version from a plist file
  private func extractVersionFromPlist(_ url: URL) throws -> String? {
    let data = try Data(contentsOf: url)
    if let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
      let version = plist["CFBundleShortVersionString"] as? String
    {
      return version
    }

    return nil
  }
}
