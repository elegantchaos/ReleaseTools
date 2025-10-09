// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 17/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Runner

struct WorkspaceSpec: Decodable {
  let name: String
  let schemes: [String]
}

struct SchemesSpec: Decodable {
  let workspace: WorkspaceSpec
}

enum ArchiveError: Runner.Error {
  case archiveFailed
  case noVersionTagAtHEAD

  func description(for session: Runner.Session) async -> String {
    switch self {
      case .archiveFailed:
        return "Archiving failed.\n\n\(await session.stderr.string)"
      case .noVersionTagAtHEAD:
        return """
          No version tag found at HEAD.
          Please create a version tag before archiving using:
            rt tag --explicit-version <version> [--increment-tag]
          """
    }
  }
}

struct ArchiveCommand: AsyncParsableCommand {
  static var configuration: CommandConfiguration {
    CommandConfiguration(
      commandName: "archive",
      abstract: "Make an archive for uploading, distribution, etc."
    )
  }

  @Option(help: "Additional xcconfig file to use when building") var xcconfig: String?
  @OptionGroup() var scheme: SchemeOption
  @OptionGroup() var platform: PlatformOption
  @OptionGroup() var options: CommonOptions

  func run() async throws {
    let parsed = try OptionParser(
      options: options,
      command: Self.configuration,
      scheme: scheme,
      platform: platform
    )

    try await Self.archive(parsed: parsed, xcconfig: xcconfig)
  }

  static func archive(parsed: OptionParser, xcconfig: String? = nil) async throws {
    let infoHeaderPath = "\(parsed.buildURL.path)/VersionInfo.h"
    let (build, commit) = try await parsed.generateHeader(
      header: infoHeaderPath, requireHEADTag: true)
    parsed.log("Archiving scheme \(parsed.scheme)...")

    let xcode = XCodeBuildRunner(parsed: parsed)
    var args = [
      "-workspace", parsed.workspace,
      "-scheme", parsed.scheme,
      "archive",
      "-archivePath", parsed.archiveURL.path,
      "-allowProvisioningUpdates",
      "INFOPLIST_PREFIX_HEADER=\(infoHeaderPath)",
      "INFOPLIST_PREPROCESS=YES",
      "CURRENT_PROJECT_VERSION=\(build)",
      "CURRENT_PROJECT_COMMIT=\(commit)",
    ]

    if let config = xcconfig {
      args.append(contentsOf: ["-xcconfig", config])
    }

    switch parsed.platform {
      case "macOS":
        args.append(contentsOf: ["-destination", "generic/platform=macOS"])
      case "iOS":
        args.append(contentsOf: ["-destination", "generic/platform=iOS"])
      case "tvOS":
        args.append(contentsOf: ["-destination", "generic/platform=tvOS"])
      case "watchOS":
        args.append(contentsOf: ["-destination", "generic/platform=watchOS"])
      default:
        break
    }

    let result = xcode.run(args)
    try await result.throwIfFailed(ArchiveError.archiveFailed)
    parsed.log("Archived scheme \(parsed.scheme).")
  }
}
