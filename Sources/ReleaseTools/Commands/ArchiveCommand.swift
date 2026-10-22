// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 17/04/2019.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Runner

/// Archives the configured scheme for a release build.
struct ArchiveCommand: AsyncParsableCommand {
  /// Optional build settings file passed to Xcode.
  @Option(help: "Additional xcconfig file to use when building") var xcconfig: String?

  /// Scheme selection supplied on the command line.
  @OptionGroup() var scheme: SchemeOption

  /// Target platform supplied on the command line.
  @OptionGroup() var platform: PlatformOption

  /// Shared workspace and diagnostic flags for this command.
  @OptionGroup() var options: CommonOptions

  /// Describes the `archive` command for ArgumentParser.
  static var configuration: CommandConfiguration {
    CommandConfiguration(
      commandName: "archive",
      abstract: "Make an archive for uploading, distribution, etc."
    )
  }

  /// Resolves command options and creates the release archive.
  func run() async throws {
    let engine = try await ReleaseEngine(
      options: options,
      scheme: scheme,
      platform: platform,
    )

    try await Self.archive(engine: engine, xcconfig: xcconfig)
  }

  /// Generates version metadata and archives the selected workspace, scheme, and platform.
  static func archive(engine: ReleaseEngine, xcconfig: String? = nil) async throws {
    let infoHeaderPath = "\(engine.buildURL.path)/VersionInfo.h"
    let buildInfo = try await engine.generateHeader(
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
      "RT_BUILD=\(buildInfo.build)",
      "RT_COMMIT=\(buildInfo.commit)",
      "RT_VERSION=\(buildInfo.version)",
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
    try await result.throwIfFailed(Error.archiveFailed)
    engine.log("Archived scheme \(engine.scheme).")
  }
}

extension ArchiveCommand {
  /// Errors emitted while archiving.
  enum Error: Swift.Error, LocalizedError {
    /// Creating the Xcode archive failed.
    case archiveFailed

    /// A user-facing description of the failure.
    var errorDescription: String? {
      switch self {
        case .archiveFailed: return "Archiving failed."
      }
    }
  }
}
