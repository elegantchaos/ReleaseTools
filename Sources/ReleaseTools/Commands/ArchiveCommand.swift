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

enum ArchiveError: RunnerError {
  case archiveFailed

  func description(for session: Runner.Session) async -> String {
    async let stderr = String(session.stderr)
    switch self {
      case .archiveFailed: return "Archiving failed.\n\n\(await stderr)"
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
    parsed.log("Updating Version Info")
    let infoHeaderPath = "\(parsed.buildURL.path)/VersionInfo.h"
    let build = try await UpdateBuildCommand.generateHeader(
      parsed: parsed, header: infoHeaderPath, repo: parsed.rootURL.path)
    parsed.log("Archiving scheme \(parsed.scheme)...")

    let xcode = XCodeBuildRunner(parsed: parsed)
    var args = [
      "-workspace", parsed.workspace, "-scheme", parsed.scheme, "archive", "-archivePath",
      parsed.archiveURL.path, "-allowProvisioningUpdates",
      "INFOPLIST_PREFIX_HEADER=\(infoHeaderPath)", "INFOPLIST_PREPROCESS=YES",
      "CURRENT_PROJECT_VERSION=\(build)",
    ]
    if let config = xcconfig {
      args.append(contentsOf: ["-xcconfig", config])
    }

    switch parsed.platform {
      case "iOS":
        args.append(contentsOf: ["-destination", "generic/platform=iOS"])
      case "tvOS":
        args.append(contentsOf: ["-destination", "generic/platform=tvOS"])
      case "watchOS":
        args.append(contentsOf: ["-destination", "generic/platform=watchOS"])
      default:
        break
    }

    let result = try xcode.run(args)
    try await result.throwIfFailed(ArchiveError.archiveFailed)
    parsed.log("Archived scheme \(parsed.scheme).")
  }
}
