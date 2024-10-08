// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 25/02/20.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Runner

enum UploadError: Error {
  case savingUploadReceiptFailed(Error)

  public var description: String {
    switch self {
      case .savingUploadReceiptFailed(let error): return "Saving upload receipt failed.\n\(error)"
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
        "--file", parsed.exportedIPAURL.path, "--output-format", "xml", "--type", parsed.platform,
      ])
    } else {
      // use api key and issuer
      uploadResult = xcrun.run([
        "altool", "--upload-app", "--apiIssuer", parsed.apiIssuer, "--apiKey", parsed.apiKey,
        "--file", parsed.exportedIPAURL.path, "--output-format", "xml", "--type", parsed.platform,
      ])
    }

    try await uploadResult.throwIfFailed(UploadRunnerError.uploadingFailed)

    parsed.log("Finished uploading.")
    do {
      let output = await uploadResult.stdout.string
      try output.write(
        to: parsed.uploadingReceiptURL, atomically: true, encoding: .utf8)
    } catch {
      throw UploadError.savingUploadReceiptFailed(error)
    }

    parsed.log("Tagging.")
    let git = GitRunner()
    let tagResult = git.run([
      "tag", parsed.versionTag, "-m", "Uploaded with \(CommandLine.name)",
    ])
    try await tagResult.throwIfFailed(GeneralError.taggingFailed)
  }
}
