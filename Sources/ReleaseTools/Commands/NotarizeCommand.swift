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

    let parsed = try OptionParser(
      requires: [.archive],
      options: options,
      command: Self.configuration,
      scheme: scheme,
      platform: platform
    )

    parsed.log("Creating zip archive for notarization.")
    let ditto = DittoRunner(parsed: parsed)

    let zipResult = ditto.zip(parsed.exportedAppURL, as: parsed.exportedZipURL)
    try await zipResult.throwIfFailed(NotarizeRunnerError.compressingFailed)

    parsed.log("Uploading \(parsed.versionTag) to notarization service.")
    let xcrun = XCRunRunner(parsed: parsed)
    let result = xcrun.run([
      "altool",
      "--notarize-app",
      "--primary-bundle-id", parsed.archive.identifier,
      "--apiIssuer", parsed.apiIssuer,
      "--apiKey", parsed.apiKey,
      "--team-id", parsed.archive.team,
      "--file", parsed.exportedZipURL.path,
      "--output-format", "xml",
    ])
    try await result.throwIfFailed(NotarizeRunnerError.notarizingFailed)

    parsed.log("Requested notarization.")
    do {
      let output = await result.stdout.string
      try output.write(to: parsed.notarizingReceiptURL, atomically: true, encoding: .utf8)
    } catch {
      throw NotarizeError.savingNotarizationReceiptFailed(error)
    }
  }
}
