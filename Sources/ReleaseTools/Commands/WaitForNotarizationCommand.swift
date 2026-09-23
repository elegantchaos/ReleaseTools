// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/02/20.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Coercion
import Foundation
import Runner

/// Waits for notarization, then staples the resulting ticket to the app.
struct WaitForNotarizationCommand: AsyncParsableCommand {
  /// Describes the `wait` command for ArgumentParser.
  static var configuration: CommandConfiguration {
    CommandConfiguration(
      commandName: "wait",
      abstract: "Wait until notarization has completed."
    )
  }

  @Option(
    help:
      "The uuid of the notarization request. Defaults to the value previously stored by the `notarize` command."
  ) var request: String?

  @OptionGroup() var platform: PlatformOption
  @OptionGroup() var options: CommonOptions

  /// Time to wait before checking the notarization status again.
  static let retryDelay = 30

  func run() async throws {
    let engine = try await ReleaseEngine(
      options: options,
      command: Self.configuration,
      platform: platform
    )

    // Validate the archive before polling, so a bad archive fails immediately.
    let archive = try engine.requireArchive()

    guard let requestUUID = request ?? savedNotarizationReceipt(engine: engine) else {
      throw Error.loadingReceiptFailed
    }

    engine.log("Requesting notarization status...")
    do {
      while !(try await check(request: requestUUID, archive: archive, engine: engine)) {
        engine.log("Will retry in \(Self.retryDelay) seconds...")
        try await Task.sleep(for: .seconds(Self.retryDelay))
        engine.log("Retrying fetch of notarization status...")
      }
    } catch let error as Error {
      throw error
    } catch {
      throw Error.fetchingStatusFailed(error)
    }

    engine.log("Tagging.")
    let tagResult = engine.git.run([
      "tag", engine.versionTag(for: archive), "-f", "-m", "Uploaded with \(CommandLine.name)",
    ])
    try await tagResult.throwIfFailed(ReleaseEngine.Error.taggingFailed)
  }

  func savedNotarizationReceipt(engine: ReleaseEngine) -> String? {
    let notarizingReceiptURL = engine.exportURL.appendingPathComponent("receipt.xml")
    guard let data = try? Data(contentsOf: notarizingReceiptURL),
      let receipt = try? PropertyListSerialization.propertyList(
        from: data, options: [], format: nil) as? [String: Any],
      let upload = receipt["notarization-upload"] as? [String: String]
    else { return nil }

    return upload["RequestUUID"]
  }

  func exportNotarized(archive: XcodeArchive, engine: ReleaseEngine) async throws {
    engine.log("Stapling notarized app.")

    do {
      let fm = FileManager.default
      try? fm.createDirectory(
        at: engine.stapledURL, withIntermediateDirectories: true, attributes: nil)

      let stapledAppURL = engine.stapledURL.appending(path: archive.name)
      try? fm.removeItem(at: stapledAppURL)
      try? fm.copyItem(at: engine.exportedAppURL(for: archive), to: stapledAppURL)
      let xcrun = XCRunRunner(engine: engine)
      let result = xcrun.run(["stapler", "staple", stapledAppURL.path])
      try await result.throwIfFailed(Error.staplingFailed)
    } catch {
      throw Error.exportingNotarizedAppFailed(error)
    }
  }

  func check(request: String, archive: XcodeArchive, engine: ReleaseEngine) async throws -> Bool {
    let xcrun = XCRunRunner(engine: engine)
    let result = xcrun.run([
      "altool",
      "--notarization-info",
      request,
      "--apiIssuer", engine.apiIssuer,
      "--apiKey", engine.apiKey,
      "--output-format", "xml",
    ])
    try await result.throwIfFailed(Error.statusRequestFailed)

    engine.log("Received response.")
    switch Self.status(fromResponse: await result.stdout.data) {
      case .success:
        engine.log("Status was success.")
        try await exportNotarized(archive: archive, engine: engine)
        return true
      case .invalid(let report):
        engine.log("Status was invalid.")
        throw Error.notarizationFailed(report)
      case .pending(let status):
        engine.log("Status was \(status).")
        return false
      case nil:
        return false
    }
  }

  /// Interprets an `altool --notarization-info` XML response.
  ///
  /// Returns `nil` when the response can't be read, so the caller retries.
  /// An invalid status carries a report built from the notarization log, fetched with `loadLog`.
  static func status(
    fromResponse data: Data,
    loadLog: (URL) -> Data? = { try? Data(contentsOf: $0) }
  ) -> Status? {
    guard
      let receipt = try? PropertyListSerialization.propertyList(
        from: data, options: [], format: nil) as? [String: Any],
      let info = receipt["notarization-info"] as? [String: Any],
      let status = info[asString: "Status"]
    else { return nil }

    switch status {
      case "success": return .success
      case "invalid": return .invalid(report(for: info, loadLog: loadLog))
      default: return .pending(status)
    }
  }

  /// Builds a readable report from an invalid response and its notarization log.
  static func report(for info: [String: Any], loadLog: (URL) -> Data?) -> String {
    let message = (info[asString: "Status Message"]) ?? ""
    var output = "\(message).\n"
    if let logFile = info[asString: "LogFileURL"],
      let url = URL(string: logFile),
      let data = loadLog(url),
      let log = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
    {
      let summary = (log[asString: "statusSummary"]) ?? ""
      output.append("\(summary).\n")
      if let issues = log["issues"] as? [[String: Any]] {
        for (index, issue) in issues.enumerated() {
          let message = issue[asString: "message"] ?? ""
          let path = issue[asString: "path"] ?? ""
          let name = URL(fileURLWithPath: path).lastPathComponent
          let severity = issue[asString: "severity"] ?? ""
          output.append("\n#\(index + 1) \(name) (\(severity)):\n\(message)\n\(path)\n")
        }
      }
    }
    return output
  }
}

extension WaitForNotarizationCommand {
  /// The notarization state reported by the status service.
  enum Status: Equatable {
    /// Notarization succeeded, so the app can be stapled.
    case success
    /// Notarization rejected the app; the report explains why.
    case invalid(String)
    /// Notarization hasn't finished; the raw status is kept for logging.
    case pending(String)
  }

  /// Errors emitted while checking and exporting a notarized app.
  enum Error: Swift.Error, LocalizedError {
    /// Fetching the notarization status threw an error.
    case fetchingStatusFailed(any Swift.Error)
    /// The notarization service rejected the app.
    case notarizationFailed(String)
    /// Preparing the stapled app threw an error.
    case exportingNotarizedAppFailed(any Swift.Error)
    /// The notarization receipt could not be loaded.
    case loadingReceiptFailed

    /// The notarization status request failed.
    case statusRequestFailed
    /// Stapling the notarized app failed.
    case staplingFailed

    /// A user-facing description of the notarization failure.
    var errorDescription: String? {
      switch self {
        case .statusRequestFailed: return "Requesting notarization status failed."
        case .staplingFailed: return "Stapling the notarized app failed."
        case .fetchingStatusFailed(let error): return "Fetching notarization status failed.\n\(error.localizedDescription)"
        case .notarizationFailed(let report): return "Notarization failed.\n\(report)"
        case .exportingNotarizedAppFailed(let error): return "Exporting notarized app failed.\n\(error.localizedDescription)"
        case .loadingReceiptFailed: return "Loading notarization receipt failed."
      }
    }
  }
}
