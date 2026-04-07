// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 25/02/20.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Runner

enum UploadError: Error {
  case uploadFileMissing(String)
  case uploadOtherError(String)
  case decodingUploadReceiptFailed(Error, String)
  case savingUploadReceiptFailed(Error)
  case uploadingFailedWithErrors([UploadReceiptError])
}

extension UploadError: LocalizedError {
  public var errorDescription: String? {
    switch self {
      case .uploadFileMissing(let raw):
        return "Upload file not found.\n\n\(raw)"

      case .uploadOtherError(let raw):
        return "Upload failed with an unknown error.\n\n\(raw)"

      case .savingUploadReceiptFailed(let error):
        return "Saving upload receipt failed.\n\(error.localizedDescription)"

      case .decodingUploadReceiptFailed(let error, let content):
        var description = "Decoding upload receipt failed.\n\(error.localizedDescription)"
        if content.isEmpty {
          description += "\n\nNo content was returned from the upload command."
        } else {
          description += "\n\nResponse content:\n\(content)"
        }
        return description

      case .uploadingFailedWithErrors(let errors):
        var log = "Upload was rejected.\n"
        for error in errors {
          log += "\n\(error.compactSummary)\n"
        }

        return log
    }
  }
}

enum UploadRunnerError: Runner.Error {
  case uploadingFailed

  func description(for session: Runner.Session) async -> String {
    switch self {
      case .uploadingFailed:
        return "Uploading failed.\n\(await session.stderr.string)"
    }
  }
}

struct UploadCommand: AsyncParsableCommand {
  static var configuration: CommandConfiguration {
    CommandConfiguration(
      commandName: "upload",
      abstract: "Upload the archived app to Apple Connect portal for processing."
    )
  }

  @OptionGroup() var scheme: SchemeOption
  @OptionGroup() var apiKey: ApiKeyOption
  @OptionGroup() var apiIssuer: ApiIssuerOption
  @OptionGroup() var platform: PlatformOption
  @OptionGroup() var options: CommonOptions

  func run() async throws {
    let engine = try await ReleaseEngine(
      requires: [.archive],
      options: options,
      command: Self.configuration,
      scheme: scheme,
      apiKey: apiKey,
      apiIssuer: apiIssuer,
      platform: platform
    )

    try await Self.upload(engine: engine)
  }

  static func upload(engine: ReleaseEngine) async throws {
    engine.log("Uploading \(engine.versionTag) to Apple Connect.")
    let xcrun = XCRunRunner(engine: engine)
    let uploadResult: Runner.Session
    uploadResult = xcrun.run([
      "altool", "--upload-app", "--apiIssuer", engine.apiIssuer, "--apiKey", engine.apiKey,
      "--file", engine.exportedIPAURL.path, "--output-format", "json", "--type", engine.platform,
    ])

    // stash a copy of the stdout and stderr in the build folder
    let stdout = await uploadResult.stdout.string
    let stderr = await uploadResult.stderr.string
    do {
      try? FileManager.default.createDirectory(at: engine.uploadURL, withIntermediateDirectories: true)
      try stdout.write(to: engine.uploadingReceiptURL, atomically: true, encoding: .utf8)
      try stderr.write(to: engine.uploadingErrorsURL, atomically: true, encoding: .utf8)
    } catch {
      throw UploadError.savingUploadReceiptFailed(error)
    }

    _ = try analyzeUploadOutput(stdout: stdout, stderr: stderr)

    // check for a non-zero result
    // unfortunately altool doesn't always return a non-zero error, so we parse
    // its structured output before falling back to the process exit status.
    try await uploadResult.throwIfFailed(UploadRunnerError.uploadingFailed)

    engine.log("Finished uploading.")

    // no errors, so tag the commit
    engine.log("Upload was accepted.")
    engine.log("Tagging.")
    let tagResult = engine.git.run([
      "tag", engine.versionTag, "-m", "Uploaded with \(CommandLine.name)",
    ])
    try await tagResult.throwIfFailed(GeneralError.taggingFailed)

  }

  static func analyzeUploadOutput(stdout: String, stderr: String) throws -> UploadReceipt? {
    let trimmedStdout = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmedStdout.isEmpty {
      do {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .dashCase
        let receipt = try decoder.decode(UploadReceipt.self, from: Data(trimmedStdout.utf8))
        if let errors = receipt.productErrors, !errors.isEmpty {
          throw UploadError.uploadingFailedWithErrors(errors)
        }

        return receipt
      } catch let error as UploadError {
        throw error
      } catch {
        if let stderrError = stderrError(stderr) {
          throw stderrError
        }

        throw UploadError.decodingUploadReceiptFailed(error, stdout)
      }
    }

    if let stderrError = stderrError(stderr) {
      throw stderrError
    }

    return nil
  }

  static func stderrError(_ stderr: String) -> UploadError? {
    for line in stderr.split(separator: "\n") {
      let string = String(line)
      if string.contains("ERROR:") {
        if string.contains("File does not exist at path") {
          return .uploadFileMissing(string)
        } else {
          return .uploadOtherError(string)
        }
      }
    }

    return nil
  }
}

struct UploadReceiptError: Codable, Sendable {
  let code: Int
  let message: String
  let underlyingErrors: [UploadReceiptError]
  let userInfo: [String: String]?
}

struct UploadReceiptDetails: Codable, Sendable {
  let deliveryUuid: String
  let transferred: String
}
struct UploadReceipt: Codable {
  let osVersion: String
  let toolPath: String
  let toolVersion: String
  let productErrors: [UploadReceiptError]?
  let successMessage: String?
  let details: UploadReceiptDetails?
}

extension UploadReceiptError {
  var compactSummary: String {
    let summary = compactMessage
    var lines = ["[\(code)] \(summary)"]

    if summary == "App sandbox not enabled." {
      lines.append("- Enable the \"com.apple.security.app-sandbox\" entitlement.")
      for executable in sandboxExecutables {
        lines.append("- Executable: \(executable)")
      }
    } else if
      let reason = userInfo?["NSLocalizedFailureReason"]?.trimmingCharacters(in: .whitespacesAndNewlines),
      !reason.isEmpty
    {
      lines.append("- \(reason)")
    }

    return lines.joined(separator: "\n")
  }

  var compactMessage: String {
    if message.hasPrefix("App sandbox not enabled.") {
      return "App sandbox not enabled."
    }

    let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
    if let sentenceEnd = trimmed.firstIndex(of: ".") {
      return String(trimmed[...sentenceEnd])
    }

    return trimmed
  }

  var sandboxExecutables: [String] {
    guard let start = message.range(of: "entitlements property list: [")?.upperBound else {
      return []
    }

    guard let end = message[start...].range(of: "] Refer")?.lowerBound else {
      return []
    }

    let slice = String(message[start..<end])
    let pattern = try? NSRegularExpression(pattern: #""([^"]+)""#)
    let range = NSRange(slice.startIndex..<slice.endIndex, in: slice)
    let matches = pattern?.matches(in: slice, range: range) ?? []

    return matches.compactMap { match in
      guard
        let capture = Range(match.range(at: 1), in: slice)
      else {
        return nil
      }

      return String(slice[capture])
    }
  }
}
