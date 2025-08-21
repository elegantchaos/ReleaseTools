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

enum UploadRunnerError: Runner.Error {
  case uploadingFailed

  func description(for session: Runner.Session) async -> String {
    async let stderr = session.stderr.string
    switch self {
      case .uploadingFailed: return "Uploading failed.\n\(await stderr)"
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
  @OptionGroup() var user: UserOption
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
      user: user,
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

    print(
      [
        "altool", "--upload-app", "--apiIssuer", parsed.apiIssuer, "--apiKey", parsed.apiKey,
        "--file", parsed.exportedIPAURL.path, "--output-format", "json", "--type", parsed.platform,
      ].joined(separator: " "))

    // upload
    try await uploadResult.throwIfFailed(UploadRunnerError.uploadingFailed)
    parsed.log("Finished uploading.")

    // check for an error from stderr, since altool usefully doesn't always return a non-zero error
    // (or maybe xcrun doesn't?)
    let stderr = await uploadResult.stderr.string
    if stderr.contains("ERROR:") {
      if stderr.contains("File does not exist at path") {
        throw UploadError.uploadFileMissing(stderr)
      } else {
        throw UploadError.uploadOtherError(stderr)
      }
    }

    // stash a copy of the output
    let output = await uploadResult.stdout.string
    do {
      try output.write(to: parsed.uploadingReceiptURL, atomically: true, encoding: .utf8)
    } catch {
      throw UploadError.savingUploadReceiptFailed(error)
    }

    // parse the output
    let receipt: UploadReceipt
    do {
      let decoder = JSONDecoder()
      decoder.keyDecodingStrategy = .dashCase
      receipt = try decoder.decode(UploadReceipt.self, from: output.data(using: .utf8)!)
    } catch {
      throw UploadError.decodingUploadReceiptFailed(error, output)
    }

    // check the receipt for errors
    if let errors = receipt.productErrors, !errors.isEmpty {
      throw UploadError.uploadingFailedWithErrors(errors)
    }

    // no errors, so tag the commit
    parsed.log("Upload was accepted.")
    parsed.log("Tagging.")
    let git = GitRunner()
    let tagResult = git.run([
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
