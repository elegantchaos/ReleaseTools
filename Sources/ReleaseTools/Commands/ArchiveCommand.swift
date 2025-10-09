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
    let engine = try ReleaseEngine(
      options: options,
      command: Self.configuration
    )

    _ = try await engine.versionTagAtHEAD()

    try await Self.archive(engine: engine, xcconfig: xcconfig)
  }

  static func archive(engine: ReleaseEngine, xcconfig: String? = nil) async throws {
    let infoHeaderPath = "\(engine.buildURL.path)/VersionInfo.h"
    let (build, commit) = try await engine.generateHeader(
      header: infoHeaderPath, requireHEADTag: true)
    engine.log("Archiving scheme \(engine.scheme)...")

    let xcode = XCodeBuildRunner(engine: engine)
    var args = [
      "-workspace", engine.workspace,
      "-scheme", engine.scheme,
      "archive",
      "-archivePath", engine.archiveURL.path,
      "-allowProvisioningUpdates",
      "INFOPLIST_PREFIX_HEADER=\(infoHeaderPath)",
      "INFOPLIST_PREPROCESS=YES",
      "RT_BUILD=\(build)",
      "RT_COMMIT=\(commit)",
    ]

    if let config = xcconfig {
      args.append(contentsOf: ["-xcconfig", config])
    }

    switch engine.platform {
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
    engine.log("Archived scheme \(engine.scheme).")
  }
}
