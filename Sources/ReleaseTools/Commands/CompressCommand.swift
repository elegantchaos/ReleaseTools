// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 17/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Runner

enum CompressError: LocalizedError {
  case compressFailed(stderr: String)

  var errorDescription: String? {
    switch self {
      case .compressFailed(let stderr):
        return "Compressing failed.\n\(stderr)"
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
    let parsed = try OptionParser(
      requires: [.archive],
      options: options,
      command: Self.configuration,
      scheme: scheme,
      platform: platform
    )

    let stapledAppURL = parsed.stapledURL.appendingPathComponent(parsed.archive.name)
    let ditto = DittoRunner(parsed: parsed)
    let destination = updates.url.appendingPathComponent(parsed.archive.versionedZipName)

    let result = ditto.zip(stapledAppURL, as: destination)
    let state = await result.waitUntilExit()
    if case .failed = state {
      let stderr = await result.stderr.string
      throw CompressError.compressFailed(stderr: stderr)
    }

    parsed.log(
      "Saving copy of archive to \(website.websiteURL.path) as \(parsed.archive.unversionedZipName)."
    )
    let latestZip = website.websiteURL.appendingPathComponent(parsed.archive.unversionedZipName)
    try? FileManager.default.removeItem(at: latestZip)
    try FileManager.default.copyItem(at: destination, to: latestZip)
  }
}
