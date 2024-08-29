// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/02/20.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Coercion
import Foundation
import Runner

import protocol ArgumentParser.AsyncParsableCommand

enum WaitForNotarizationError: Error {
  case fetchingNotarizationStatusFailed(_ result: Runner.RunningProcess)
  case fetchingNotarizationStatusThrew(_ error: Error)
  case loadingNotarizationReceiptFailed
  case notarizationFailed(_ output: String)
  case exportingNotarizedAppFailed(_ result: Runner.RunningProcess)
  case exportingNotarizedAppThrew(_ error: Error)
  case missingArchive

  public var description: String {
    switch self {
    case .fetchingNotarizationStatusFailed(let result):
      return "Fetching notarization status failed.\n\(result)"
    case .fetchingNotarizationStatusThrew(let error):
      return "Fetching notarization status failed.\n\(error)"
    case .loadingNotarizationReceiptFailed: return "Loading notarization receipt failed."
    case .notarizationFailed(let output): return "Notarization failed.\n\(output)"
    case .exportingNotarizedAppFailed(let result):
      return "Exporting notarized app failed.\n\(result)"
    case .exportingNotarizedAppThrew(let error): return "Exporting notarized app failed.\n\(error)"
    case .missingArchive: return "Exporting notarized app couldn't find archive."
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

  @OptionGroup() var user: UserOption
  @OptionGroup() var platform: PlatformOption
  @OptionGroup() var options: CommonOptions

  func run() async throws {
    let parsed = try OptionParser(
      requires: [.archive],
      options: options,
      command: Self.configuration,
      user: user,
      platform: platform
    )

    guard let requestUUID = request ?? savedNotarizationReceipt(parsed: parsed) else {
      throw WaitForNotarizationError.loadingNotarizationReceiptFailed
    }

    parsed.log("Requesting notarization status...")
    await check(request: requestUUID, parsed: parsed)

    parsed.log("Tagging.")
    let git = GitRunner()
    let tagResult = try git.run([
      "tag", parsed.versionTag, "-f", "-m", "Uploaded with \(CommandLine.name)",
    ])
    try await tagResult.throwIfFailed(GeneralError.taggingFailed(tagResult))
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

  func exportNotarized(parsed: OptionParser) async {
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
        let result = try xcrun.run(["stapler", "staple", stapledAppURL.path])
        try await result.throwIfFailed(WaitForNotarizationError.exportingNotarizedAppFailed(result))
      } else {
        throw WaitForNotarizationError.missingArchive
      }
    } catch {
      throw WaitForNotarizationError.exportingNotarizedAppThrew(error)
    }
  }

  func check(request: String, parsed: OptionParser) async {
    let xcrun = XCRunRunner(parsed: parsed)
    do {
      let result = try xcrun.run([
        "altool", "--notarization-info", request, "--username", parsed.user, "--password",
        "@keychain:AC_PASSWORD", "--output-format", "xml",
      ])
      if result.status != 0 {
        parsed.fail(WaitForNotarizationError.fetchingNotarizationStatusFailed(result))
      }

      parsed.log("Received response.")
      if let data = result.stdout.data(using: .utf8),
        let receipt = try? PropertyListSerialization.propertyList(
          from: data, options: [], format: nil) as? [String: Any],
        let info = receipt["notarization-info"] as? [String: Any],
        let status = info[asString: "Status"]
      {
        parsed.log("Status was \(status).")
        if status == "success" {
          exportNotarized(parsed: parsed)
          return
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
    } catch {
      parsed.fail(WaitForNotarizationError.fetchingNotarizationStatusThrew(error))
    }

    let delay = 30
    let nextCheck = DispatchTime.now() + .seconds(delay)
    parsed.log("Will retry in \(delay) seconds...")
    DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: nextCheck) {
      parsed.log("Retrying fetch of notarization status...")
      self.check(request: request, parsed: parsed)
    }

  }
}
