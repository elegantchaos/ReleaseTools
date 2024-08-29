// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/02/20.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Runner

enum NotarizeError: Error, Sendable {
  case compressingFailed(_ result: Runner.RunningProcess)
  case notarizingFailed(
    _ result: Runner.RunningProcess
  )
  case savingNotarizationReceiptFailed(_ error: Error)

  public var description: String {
    switch self {
    case .compressingFailed(let result): return "Compressing failed.\n\(result)"
    case .notarizingFailed(let result): return "Notarizing failed.\n\(result)"
    case .savingNotarizationReceiptFailed(let error):
      return "Saving notarization receipt failed.\n\(error)"
    }
  }
}

extension Result {
}

struct NotarizeCommand: AsyncParsableCommand {
  static var configuration: CommandConfiguration {
    CommandConfiguration(
      commandName: "notarize",
      abstract: "Notarize the compressed archive."
    )
  }

  @OptionGroup() var scheme: SchemeOption
  @OptionGroup() var user: UserOption
  @OptionGroup() var platform: PlatformOption
  @OptionGroup() var options: CommonOptions

  func run() async throws {

    let parsed = try OptionParser(
      requires: [.archive],
      options: options,
      command: Self.configuration,
      scheme: scheme,
      user: user,
      platform: platform
    )

    parsed.log("Creating archive for notarization.")
    let ditto = DittoRunner(parsed: parsed)

    let zipResult = try ditto.zip(parsed.exportedAppURL, as: parsed.exportedZipURL)
    try await zipResult.throwIfFailed(NotarizeError.compressingFailed(zipResult))

    parsed.log("Uploading \(parsed.versionTag) to notarization service.")
    let xcrun = XCRunRunner(parsed: parsed)
    let result = try xcrun.run([
      "altool", "--notarize-app", "--primary-bundle-id", parsed.archive.identifier, "--username",
      parsed.user, "--password", "@keychain:AC_PASSWORD", "--team-id", parsed.archive.team,
      "--file", parsed.exportedZipURL.path, "--output-format", "xml",
    ])
    try await result.throwIfFailed(NotarizeError.notarizingFailed(result))

    parsed.log("Requested notarization.")
    do {
      let output = await String(result.stdout)
      try output.write(to: parsed.notarizingReceiptURL, atomically: true, encoding: .utf8)
    } catch {
      throw NotarizeError.savingNotarizationReceiptFailed(error)
    }
  }
}
