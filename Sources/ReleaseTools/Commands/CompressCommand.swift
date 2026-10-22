// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 17/04/2019.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Runner

/// Compresses an exported application and stages the distribution archives.
struct CompressCommand: AsyncParsableCommand {
  /// Scheme selection supplied on the command line.
  @OptionGroup() var scheme: SchemeOption

  /// Target platform supplied on the command line.
  @OptionGroup() var platform: PlatformOption

  /// Destination of the website repository.
  @OptionGroup() var website: WebsiteOption

  /// Destination of published application updates.
  @OptionGroup() var updates: UpdatesOption

  /// Shared workspace and diagnostic flags for this command.
  @OptionGroup() var options: CommonOptions

  /// Describes the `compress` command for ArgumentParser.
  static var configuration: CommandConfiguration {
    CommandConfiguration(
      commandName: "compress",
      abstract: "Compress the output of the export command for distribution."
    )
  }

  /// Copies a compressed notarized app into the configured website update paths.
  func run() async throws {
    let engine = try await ReleaseEngine(
      options: options,
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
