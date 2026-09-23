// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/02/20.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Runner

/// Submits the exported application to Apple's notarization service.
struct NotarizeCommand: AsyncParsableCommand {
  /// Describes the `notarize` command for ArgumentParser.
  static var configuration: CommandConfiguration {
    CommandConfiguration(
      commandName: "notarize",
      abstract: "Notarize the compressed archive."
    )
  }

  @OptionGroup() var scheme: SchemeOption
  @OptionGroup() var platform: PlatformOption
  @OptionGroup() var options: CommonOptions

  func run() async throws {

    let engine = try await ReleaseEngine(
      options: options,
      command: Self.configuration,
      scheme: scheme,
      platform: platform
    )

    let archive = try engine.requireArchive()
    engine.log("Creating zip archive for notarization.")
    let ditto = DittoRunner(engine: engine)

    let zipResult = ditto.zip(engine.exportedAppURL(for: archive), as: engine.exportedZipURL)
    try await zipResult.throwIfFailed(Error.compressingFailed)

    engine.log("Uploading \(engine.versionTag(for: archive)) to notarization service.")
    let xcrun = XCRunRunner(engine: engine)
    let result = xcrun.run([
      "altool",
      "--notarize-app",
      "--primary-bundle-id", archive.identifier,
      "--apiIssuer", engine.apiIssuer,
      "--apiKey", engine.apiKey,
      "--team-id", archive.team,
      "--file", engine.exportedZipURL.path,
      "--output-format", "xml",
    ])
    try await result.throwIfFailed(Error.notarizingFailed)

    engine.log("Requested notarization.")
    do {
      let output = await result.stdout.string
      try output.write(to: engine.notarizingReceiptURL, atomically: true, encoding: String.Encoding.utf8)
    } catch {
      throw Error.savingNotarizationReceiptFailed(error)
    }
  }
}

extension NotarizeCommand {
  /// Errors emitted while submitting the app for notarization.
  enum Error: Swift.Error, LocalizedError {
    /// Saving the notarization receipt failed.
    case savingNotarizationReceiptFailed(any Swift.Error)

    /// Compressing the app for notarization failed.
    case compressingFailed
    /// Submitting the app to the notarization service failed.
    case notarizingFailed

    /// A user-facing description of the failure.
    var errorDescription: String? {
      switch self {
        case .compressingFailed: return "Compressing failed."
        case .notarizingFailed: return "Notarizing failed."
        case .savingNotarizationReceiptFailed(let error):
          return "Saving notarization receipt failed.\n\(error.localizedDescription)"
      }
    }
  }
}
