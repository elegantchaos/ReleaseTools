// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 25/02/20.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Runner

enum UploadError: Error {
  case decodingUploadReceiptFailed(Error)
  case savingUploadReceiptFailed(Error)
  case uploadingFailedWithErrors([UploadReceiptError])
}

extension UploadError: LocalizedError {
  public var errorDescription: String? {
    switch self {
      case .savingUploadReceiptFailed(let error):
        return "Saving upload receipt failed.\n\(error.localizedDescription)"

      case .decodingUploadReceiptFailed(let error):
        return "Decoding upload receipt failed.\n\(error.localizedDescription)"

      case .uploadingFailedWithErrors(let errors):
        var log = "Upload was rejected with errors."
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
    if parsed.apiKey.isEmpty {
      // use username & password
      uploadResult = xcrun.run([
        "altool", "--upload-app", "--username", parsed.user, "--password", "@keychain:AC_PASSWORD",
        "--file", parsed.exportedIPAURL.path, "--output-format", "json", "--type", parsed.platform,
      ])
    } else {
      // use api key and issuer
      uploadResult = xcrun.run([
        "altool", "--upload-app", "--apiIssuer", parsed.apiIssuer, "--apiKey", parsed.apiKey,
        "--file", parsed.exportedIPAURL.path, "--output-format", "json", "--type", parsed.platform,
      ])
    }

    try await uploadResult.throwIfFailed(UploadRunnerError.uploadingFailed)

    parsed.log("Finished uploading.")
    let output = await uploadResult.stdout.string
    do {
      try output.write(to: parsed.uploadingReceiptURL, atomically: true, encoding: .utf8)
    } catch {
      throw UploadError.savingUploadReceiptFailed(error)
    }

    let receipt: UploadReceipt
    do {
      let decoder = JSONDecoder()
      decoder.keyDecodingStrategy = .dashCase
      receipt = try decoder.decode(UploadReceipt.self, from: output.data(using: .utf8)!)
    } catch {
      throw UploadError.decodingUploadReceiptFailed(error)
    }

    guard receipt.productErrors.isEmpty else {
      throw UploadError.uploadingFailedWithErrors(receipt.productErrors)
    }

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
struct UploadReceipt: Codable {
  let osVersion: String
  let toolPath: String
  let toolVersion: String
  let productErrors: [UploadReceiptError]
}
