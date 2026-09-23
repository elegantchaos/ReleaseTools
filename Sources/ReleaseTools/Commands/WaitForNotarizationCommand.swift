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
    let data = await result.stdout.data
    if let receipt = try? PropertyListSerialization.propertyList(
      from: data, options: [], format: nil) as? [String: Any],
      let info = receipt["notarization-info"] as? [String: Any],
      let status = info[asString: "Status"]
    {
      engine.log("Status was \(status).")
      if status == "success" {
        try await exportNotarized(archive: archive, engine: engine)
        return true
      } else if status == "invalid" {
        let message = (info[asString: "Status Message"]) ?? ""
        var output = "\(message).\n"
        if let logFile = info[asString: "LogFileURL"],
          let url = URL(string: logFile),
          let data = try? Data(contentsOf: url),
          let log = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        {
          let summary = (log[asString: "statusSummary"]) ?? ""
          output.append("\(summary).\n")
          if let issues = log["issues"] as? [[String: Any]] {
            var count = 1
            for issue in issues {
              let message = issue[asString: "message"] ?? ""
              let path = issue[asString: "path"] ?? ""
              let name = URL(fileURLWithPath: path).lastPathComponent
              let severity = issue[asString: "severity"] ?? ""
              output.append("\n#\(count) \(name) (\(severity)):\n\(message)\n\(path)\n")
              count += 1
            }
          }
        }

        engine.fail(Error.notarizationFailed(output))
      }
    }

    return false
  }
}

extension WaitForNotarizationCommand {
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
        case .notarizationFailed: return "Notarization failed."
        case .exportingNotarizedAppFailed(let error): return "Exporting notarized app failed.\n\(error.localizedDescription)"
        case .loadingReceiptFailed: return "Loading notarization receipt failed."
      }
    }
  }
}
