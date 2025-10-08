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
          log += "\n\(error.message) (\(error.code)):\n"
          if let userInfo = error.userInfo {
            if let reason = userInfo["NSLocalizedFailureReason"] {
              log += "- \(reason)\n"
            }
          }
        }

        return log
    }
  }
}

enum UploadRunnerError: LocalizedError {
  case uploadingFailed(stderr: String)

  var errorDescription: String? {
    switch self {
      case .uploadingFailed(let stderr):
        return "Uploading failed.\n\(stderr)"
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
    let parsed = try OptionParser(
      requires: [.archive],
      options: options,
      command: Self.configuration,
      scheme: scheme,
      apiKey: apiKey,
      apiIssuer: apiIssuer,
      platform: platform
    )

    try await Self.upload(parsed: parsed)
  }

  static func upload(parsed: OptionParser) async throws {
    parsed.log("Uploading \(parsed.versionTag) to Apple Connect.")
    let xcrun = XCRunRunner(parsed: parsed)
    let uploadResult: Runner.Session
    uploadResult = xcrun.run([
      "altool", "--upload-app", "--apiIssuer", parsed.apiIssuer, "--apiKey", parsed.apiKey,
      "--file", parsed.exportedIPAURL.path, "--output-format", "json", "--type", parsed.platform,
    ])

    // stash a copy of the stdout and stderr in the build folder
    let stdout = await uploadResult.stdout.string
    let stderr = await uploadResult.stderr.string
    do {
      try? FileManager.default.createDirectory(at: parsed.uploadURL, withIntermediateDirectories: true)
      try stdout.write(to: parsed.uploadingReceiptURL, atomically: true, encoding: .utf8)
      try stderr.write(to: parsed.uploadingErrorsURL, atomically: true, encoding: .utf8)
    } catch {
      throw UploadError.savingUploadReceiptFailed(error)
    }

    // check for a non-zero result
    // unfortunately altool doesn't always return a non-zero error
    // (or maybe xcrun doesn't pass it on?)
    let uploadState = await uploadResult.waitUntilExit()
    if case .failed = uploadState {
      throw UploadRunnerError.uploadingFailed(stderr: stderr)
    }

    parsed.log("Finished uploading.")

    // try to parse the output
    let receipt: UploadReceipt
    do {
      let decoder = JSONDecoder()
      decoder.keyDecodingStrategy = .dashCase
      receipt = try decoder.decode(UploadReceipt.self, from: stdout.data(using: .utf8)!)
    } catch {
      // we couldn't parse the output - see if we can find an error message in stderr instead
      for await line in await uploadResult.stderr.lines {
        if line.contains("ERROR:") {
          if line.contains("File does not exist at path") {
            throw UploadError.uploadFileMissing(line)
          } else {
            throw UploadError.uploadOtherError(line)
          }
        }
      }

      // no errors found in stderr, so just report the decoding error
      throw UploadError.decodingUploadReceiptFailed(error, stdout)
    }

    // check the parsed receipt for errors
    if let errors = receipt.productErrors, !errors.isEmpty {
      throw UploadError.uploadingFailedWithErrors(errors)
    }

    // no errors, so tag the commit
    parsed.log("Upload was accepted.")
    parsed.log("Tagging.")
    let tagResult = parsed.git.run([
      "tag", parsed.versionTag, "-m", "Uploaded with \(CommandLine.name)",
    ])
    try await tagResult.throwIfFailed(GeneralError.taggingFailed)

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
