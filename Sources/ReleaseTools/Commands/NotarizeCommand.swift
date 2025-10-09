// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/02/20.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Runner

enum NotarizeError: Error {
  case savingNotarizationReceiptFailed(Error)
}

extension NotarizeError: LocalizedError {
  /// A description of the error.
  public var errorDescription: String? {
    switch self {
      case .savingNotarizationReceiptFailed(let error):
        return "Saving notarization receipt failed.\n\(error.localizedDescription)"
    }
  }
}

enum NotarizeRunnerError: Runner.Error {
  case compressingFailed
  case notarizingFailed

  func description(for session: Runner.Session) async -> String {
    switch self {
      case .compressingFailed:
        return "Compressing failed.\n\(await session.stderr.string)"
      case .notarizingFailed:
        return "Notarizing failed.\n\(await session.stderr.string)"
    }
  }
}

struct NotarizeCommand: AsyncParsableCommand {
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

    let engine = try ReleaseEngine(
      requires: [.archive],
      options: options,
      command: Self.configuration,
      scheme: scheme,
      platform: platform
    )

    engine.log("Creating zip archive for notarization.")
    let ditto = DittoRunner(engine: engine)

    let zipResult = ditto.zip(engine.exportedAppURL, as: engine.exportedZipURL)
    try await zipResult.throwIfFailed(NotarizeRunnerError.compressingFailed)

    engine.log("Uploading \(engine.versionTag) to notarization service.")
    let xcrun = XCRunRunner(engine: engine)
    let result = xcrun.run([
      "altool",
      "--notarize-app",
      "--primary-bundle-id", engine.archive.identifier,
      "--apiIssuer", engine.apiIssuer,
      "--apiKey", engine.apiKey,
      "--team-id", engine.archive.team,
      "--file", engine.exportedZipURL.path,
      "--output-format", "xml",
    ])
    try await result.throwIfFailed(NotarizeRunnerError.notarizingFailed)

    engine.log("Requested notarization.")
    do {
      let output = await result.stdout.string
      try output.write(to: engine.notarizingReceiptURL, atomically: true, encoding: String.Encoding.utf8)
    } catch {
      throw NotarizeError.savingNotarizationReceiptFailed(error)
    }
  }
}
