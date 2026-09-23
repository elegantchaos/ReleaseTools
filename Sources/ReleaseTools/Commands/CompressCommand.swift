// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 17/04/2019.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Runner

/// Compresses an exported application and stages the distribution archives.
struct CompressCommand: AsyncParsableCommand {
  /// Describes the `compress` command for ArgumentParser.
  static var configuration: CommandConfiguration {
    CommandConfiguration(
      commandName: "compress",
      abstract: "Compress the output of the export command for distribution."
    )
  }

  @OptionGroup() var scheme: SchemeOption
  @OptionGroup() var platform: PlatformOption
  @OptionGroup() var website: WebsiteOption
  @OptionGroup() var updates: UpdatesOption
  @OptionGroup() var options: CommonOptions

  func run() async throws {
    let engine = try await ReleaseEngine(
      options: options,
      command: Self.configuration,
      scheme: scheme,
      platform: platform
    )

    let archive = try engine.requireArchive()
    let stapledAppURL = engine.stapledURL.appending(path: archive.name)
    let ditto = DittoRunner(engine: engine)
    let destination = updates.url.appending(path: archive.versionedZipName)

    let result = ditto.zip(stapledAppURL, as: destination)
    try await result.throwIfFailed(Error.compressFailed)

    engine.log(
      "Saving copy of archive to \(website.websiteURL.path) as \(archive.unversionedZipName)."
    )
    let latestZip = website.websiteURL.appending(path: archive.unversionedZipName)
    try? FileManager.default.removeItem(at: latestZip)
    try FileManager.default.copyItem(at: destination, to: latestZip)
  }
}

extension CompressCommand {
  /// Errors emitted while compressing the release archive.
  enum Error: Swift.Error, LocalizedError {
    /// The compression subprocess failed.
    case compressFailed

    /// A user-facing description of the failure.
    var errorDescription: String? {
      switch self {
        case .compressFailed: return "Compressing failed."
      }
    }
  }
}
