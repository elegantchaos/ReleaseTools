// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 17/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Runner

enum ExportError: Error {
  case writingOptionsFailed(Error)
}

extension ExportError: LocalizedError {
  /// A description of the error.
  public var errorDescription: String? {
    switch self {
      case .writingOptionsFailed(let error): return "Writing export options file failed.\n\(error.localizedDescription)"
    }
  }
}

enum ExportRunnerError: Runner.Error {
  case exportFailed

  func description(for session: Runner.Session) async -> String {
    switch self {
      case .exportFailed:
        return "Exporting failed.\n\(await session.stderr.string)"
    }
  }
}

struct ExportCommand: AsyncParsableCommand {
  static var configuration: CommandConfiguration {
    CommandConfiguration(
      commandName: "export",
      abstract: "Export an executable from the output of the archive command."
    )
  }

  @Flag(help: "Export for distribution outside of the appstore.") var distribution = false
  @OptionGroup() var scheme: SchemeOption
  @OptionGroup() var platform: PlatformOption
  @OptionGroup() var options: CommonOptions

  func run() async throws {
    let parsed = try OptionParser(
      options: options,
      command: Self.configuration,
      scheme: scheme,
      platform: platform
    )

    try await Self.export(parsed: parsed, distribution: distribution)
  }

  static func export(parsed: OptionParser, distribution: Bool = false) async throws {
    parsed.log(
      "Generating export options for \(distribution ? "direct" : "appstore") distribution.")
    do {
      let exportOptions = [
        "iCloudContainerEnvironment": "Production",
        "signingStyle": "automatic",
        "method": distribution ? "developer-id" : "app-store-connect",
      ]
      let data = try PropertyListSerialization.data(
        fromPropertyList: exportOptions, format: .xml, options: 0)
      try data.write(to: parsed.exportOptionsURL)
    } catch {
      throw ExportError.writingOptionsFailed(error)
    }

    parsed.log("Exporting \(parsed.scheme)...")
    let xcode = XCodeBuildRunner(parsed: parsed)
    try? FileManager.default.removeItem(at: parsed.exportURL)
    let result = xcode.run([
      "-exportArchive", "-archivePath", parsed.archiveURL.path, "-exportPath",
      parsed.exportURL.path, "-exportOptionsPlist", parsed.exportOptionsURL.path,
      "-allowProvisioningUpdates",
    ])

    try await result.throwIfFailed(ExportRunnerError.exportFailed)
    parsed.log("Exported \(parsed.scheme).")
  }
}
