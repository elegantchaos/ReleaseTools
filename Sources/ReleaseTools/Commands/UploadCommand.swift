// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 25/02/2020.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Runner

/// Uploads an exported build to App Store Connect.
struct UploadCommand: AsyncParsableCommand {
  /// Scheme selection supplied on the command line.
  @OptionGroup() var scheme: SchemeOption

  /// App Store Connect API key selection.
  @OptionGroup() var apiKey: ApiKeyOption

  /// App Store Connect API issuer selection.
  @OptionGroup() var apiIssuer: ApiIssuerOption

  /// Target platform supplied on the command line.
  @OptionGroup() var platform: PlatformOption

  /// Shared workspace and diagnostic flags for this command.
  @OptionGroup() var options: CommonOptions

  /// Describes the `upload` command for ArgumentParser.
  static var configuration: CommandConfiguration {
    CommandConfiguration(
      commandName: "upload",
      abstract: "Upload the archived app to Apple Connect portal for processing."
    )
  }

  /// Creates the release engine and submits the exported package.
  func run() async throws {
    let engine = try await ReleaseEngine(
      options: options,
      scheme: scheme,
      apiKey: apiKey,
      apiIssuer: apiIssuer,
      platform: platform
    )

    try await Self.upload(engine: engine)
  }

  /// Uploads the package, saves diagnostic output, and tags an accepted submission.
  static func upload(engine: ReleaseEngine) async throws {
    let archive = try engine.requireArchive()
    engine.log("Uploading \(engine.versionTag(for: archive)) to Apple Connect.")
    let xcrun = XCRunRunner(engine: engine)
    let uploadResult = xcrun.run([
      "altool", "--upload-app", "--apiIssuer", engine.apiIssuer, "--apiKey", engine.apiKey,
      "--file", engine.exportedPackageURL(for: archive).path, "--output-format", "json", "--type", engine.platform,
    ])

    // Preserve the upload transcript for later diagnosis.
    let stdout = await uploadResult.stdout.string
    let stderr = await uploadResult.stderr.string
    do {
      try? FileManager.default.createDirectory(at: engine.uploadURL, withIntermediateDirectories: true)
      try stdout.write(to: engine.uploadingReceiptURL, atomically: true, encoding: .utf8)
      try stderr.write(to: engine.uploadingErrorsURL, atomically: true, encoding: .utf8)
    } catch {
      throw Error.savingReceiptFailed(error)
    }

    _ = try analyzeUploadOutput(stdout: stdout, stderr: stderr)

    // Parse structured errors before trusting the unreliable process status.
    try await uploadResult.throwIfFailed(Error.uploadingFailed)

    engine.log("Finished uploading.")

    engine.log("Upload was accepted.")
    engine.log("Tagging.")
    let tagResult = engine.git.run([
      "tag", engine.versionTag(for: archive), "-m", "Uploaded with \(CommandLine.name)",
    ])
    try await tagResult.throwIfFailed(ReleaseEngine.Error.taggingFailed)

  }

  /// Decodes the receipt and reports structured rejections before falling back to stderr.
  static func analyzeUploadOutput(stdout: String, stderr: String) throws -> UploadReceipt? {
    let trimmedStdout = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmedStdout.isEmpty {
      do {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .dashCase
        let receipt = try decoder.decode(UploadReceipt.self, from: Data(trimmedStdout.utf8))
        if let errors = receipt.productErrors, !errors.isEmpty {
          let xcodeVersion = errors.contains(where: \.isUnsupportedXcode) ? receipt.xcodeVersion : nil
          throw Error.rejected(errors, xcodeVersion: xcodeVersion)
        }

        return receipt
      } catch let error as Error {
        throw error
      } catch {
        if let stderrError = stderrError(stderr) {
          throw stderrError
        }

        throw Error.decodingReceiptFailed(error, stdout)
      }
    }

    if let stderrError = stderrError(stderr) {
      throw stderrError
    }

    return nil
  }

  /// Extracts a missing-file error or the final error line from unstructured upload output.
  static func stderrError(_ stderr: String) -> Error? {
    var lastErrorLine: String?

    for line in stderr.split(separator: "\n") {
      let string = String(line)
      guard string.contains("ERROR:") else {
        continue
      }

      if string.contains("File does not exist at path") {
        return .uploadFileMissing(string)
      }

      lastErrorLine = string
    }

    if let lastErrorLine {
      return .uploadOtherError(lastErrorLine)
    }

    return nil
  }
}

extension UploadCommand {
  /// Errors emitted while saving or interpreting upload results.
  enum Error: Swift.Error, LocalizedError {
    /// The package selected for upload does not exist.
    case uploadFileMissing(String)

    /// The upload tool returned an unrecognized error.
    case uploadOtherError(String)

    /// Decoding a structured upload receipt failed.
    case decodingReceiptFailed(any Swift.Error, String)

    /// Saving the upload transcript failed.
    case savingReceiptFailed(any Swift.Error)

    /// App Store Connect rejected the upload, optionally identifying the upload application's version and build.
    case rejected([UploadReceiptError], xcodeVersion: String? = nil)

    /// The upload subprocess failed.
    case uploadingFailed

    /// A user-facing description of the upload failure.
    var errorDescription: String? {
      switch self {
        case .uploadingFailed: return "Uploading failed."
        case .uploadFileMissing(let raw): return "Upload file not found.\n\n\(raw)"
        case .uploadOtherError(let raw): return "Upload failed with an unknown error.\n\n\(raw)"
        case .savingReceiptFailed(let error): return "Saving upload receipt failed.\n\(error.localizedDescription)"
        case .decodingReceiptFailed(let error, let content):
          return "Decoding upload receipt failed.\n\(error.localizedDescription)\n\n\(content.isEmpty ? "No content was returned from the upload command." : "Response content:\n\(content)")"
        case .rejected(let errors, let xcodeVersion):
          let alreadyReleased = errors.contains(where: \.isAlreadyReleased)
          let headline = alreadyReleased ? "\nThis version has already been released.\n- Increase CFBundleShortVersionString before submitting a new build.\n" : ""
          let summaries =
            errors
            .filter { !(alreadyReleased && ($0.isAlreadyReleased || $0.isInvalidPreReleaseTrainError)) }
            .map { "\n\($0.compactSummary(xcodeVersion: xcodeVersion))\n" }
            .joined()
          return "Upload was rejected.\n\(headline)\(summaries)"
      }
    }
  }
}
