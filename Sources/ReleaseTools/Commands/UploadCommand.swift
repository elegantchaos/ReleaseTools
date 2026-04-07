// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 25/02/2020.
//  Copyright © 2020 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Runner

/// Errors produced while preparing, saving, or interpreting upload results.
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

/// Runner-level failure used when the upload subprocess exits unsuccessfully.
enum UploadRunnerError: Runner.Error {
  case uploadingFailed

  func description(for session: Runner.Session) async -> String {
    switch self {
      case .uploadingFailed:
        return "Uploading failed.\n\(await session.stderr.string)"
    }
  }
}

/// Uploads an exported build to App Store Connect.
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
