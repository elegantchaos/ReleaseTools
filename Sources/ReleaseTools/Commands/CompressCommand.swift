// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 17/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Runner

enum CompressError: Runner.Error {
  case compressFailed

  func description(for session: Runner.Session) async -> String {
    switch self {
      case .compressFailed:
        return "Compressing failed.\n\(await session.stderr.string)"
    }
  }
}

struct CompressCommand: AsyncParsableCommand {
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
    let destination = updates.url.appendingPathComponent(archive.versionedZipName)

    let result = ditto.zip(stapledAppURL, as: destination)
    try await result.throwIfFailed(CompressError.compressFailed)

    engine.log(
      "Saving copy of archive to \(website.websiteURL.path) as \(archive.unversionedZipName)."
    )
    let latestZip = website.websiteURL.appendingPathComponent(archive.unversionedZipName)
    try? FileManager.default.removeItem(at: latestZip)
    try FileManager.default.copyItem(at: destination, to: latestZip)
  }
}
