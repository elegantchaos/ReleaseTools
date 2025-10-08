// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/02/20.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Coercion
import Foundation
import Runner

enum WaitForNotarizationError: Error {
  case fetchingNotarizationStatusThrew(Error)
  case notarizationFailed(String)
  case exportingNotarizedAppThrew(Error)
  case missingArchive
  case loadingNotarizationReceiptFailed
}
extension WaitForNotarizationError: LocalizedError {
  public var errorDescription: String? {
    switch self {
      case .fetchingNotarizationStatusThrew(let error):
        return "Fetching notarization status failed.\n\(error)"
      case .notarizationFailed:
        return "Notarization failed."
      case .exportingNotarizedAppThrew(let error): return "Exporting notarized app failed.\n\(error)"
      case .missingArchive: return "Exporting notarized app couldn't find archive."
      case .loadingNotarizationReceiptFailed:
        return "Loading notarization receipt failed."
    }
  }
}

enum WaitForNotarizationRunnerError: Runner.Error {
  case fetchingNotarizationStatusFailed
  case exportingNotarizedAppFailed

  func description(for session: Runner.Session) async -> String {
    async let stderr = session.stderr.string
    switch self {
      case .fetchingNotarizationStatusFailed:
        return "Fetching notarization status failed.\n\(await stderr)"
      case .exportingNotarizedAppFailed:
        return "Exporting notarized app failed.\n\(await stderr)"
    }
  }
}
struct WaitForNotarizationCommand: AsyncParsableCommand {
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
    let parsed = try OptionParser(
      requires: [.archive],
      options: options,
      command: Self.configuration,
      platform: platform
    )

    guard let requestUUID = request ?? savedNotarizationReceipt(parsed: parsed) else {
      throw WaitForNotarizationError.loadingNotarizationReceiptFailed
    }

    parsed.log("Requesting notarization status...")
    do {
      while !(try await check(request: requestUUID, parsed: parsed)) {
        parsed.log("Will retry in \(Self.retryDelay) seconds...")
        try await Task.sleep(for: .seconds(Self.retryDelay))
        parsed.log("Retrying fetch of notarization status...")
      }
    } catch {
      throw WaitForNotarizationError.fetchingNotarizationStatusThrew(error)
    }

    parsed.log("Tagging.")
    let git = parsed.gitRunnerAtRoot()
    let tagResult = git.run([
      "tag", parsed.versionTag, "-f", "-m", "Uploaded with \(CommandLine.name)",
    ])
    try await tagResult.throwIfFailed(GeneralError.taggingFailed)
  }

  func savedNotarizationReceipt(parsed: OptionParser) -> String? {
    let notarizingReceiptURL = parsed.exportURL.appendingPathComponent("receipt.xml")
    guard let data = try? Data(contentsOf: notarizingReceiptURL),
      let receipt = try? PropertyListSerialization.propertyList(
        from: data, options: [], format: nil) as? [String: Any],
      let upload = receipt["notarization-upload"] as? [String: String]
    else { return nil }

    return upload["RequestUUID"]
  }

  func exportNotarized(parsed: OptionParser) async throws {
    parsed.log("Stapling notarized app.")

    do {
      let fm = FileManager.default
      try? fm.createDirectory(
        at: parsed.stapledURL, withIntermediateDirectories: true, attributes: nil)

      if let archive = parsed.archive {
        let stapledAppURL = parsed.stapledURL.appendingPathComponent(archive.name)
        try? fm.removeItem(at: stapledAppURL)
        try? fm.copyItem(at: parsed.exportedAppURL, to: stapledAppURL)
        let xcrun = XCRunRunner(parsed: parsed)
        let result = xcrun.run(["stapler", "staple", stapledAppURL.path])
        try await result.throwIfFailed(WaitForNotarizationRunnerError.exportingNotarizedAppFailed)
      } else {
        throw WaitForNotarizationError.missingArchive
      }
    } catch {
      throw WaitForNotarizationError.exportingNotarizedAppThrew(error)
    }
  }

  func check(request: String, parsed: OptionParser) async throws -> Bool {
    let xcrun = XCRunRunner(parsed: parsed)
    let result = xcrun.run([
      "altool",
      "--notarization-info",
      request,
      "--apiIssuer", parsed.apiIssuer,
      "--apiKey", parsed.apiKey,
      "--output-format", "xml",
    ])
    try await result.throwIfFailed(WaitForNotarizationRunnerError.fetchingNotarizationStatusFailed)

    parsed.log("Received response.")
    let data = await result.stdout.data
    if let receipt = try? PropertyListSerialization.propertyList(
      from: data, options: [], format: nil) as? [String: Any],
      let info = receipt["notarization-info"] as? [String: Any],
      let status = info[asString: "Status"]
    {
      parsed.log("Status was \(status).")
      if status == "success" {
        try await exportNotarized(parsed: parsed)
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

        parsed.fail(WaitForNotarizationError.notarizationFailed(output))
      }
    }

    return false
  }
}
