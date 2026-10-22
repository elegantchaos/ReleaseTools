// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 17/04/2019.
//  Copyright © 2019 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Runner

/// Exports an archive for App Store Connect or direct distribution.
struct ExportCommand: AsyncParsableCommand {
  /// Whether export options select distribution outside the App Store.
  @Flag(help: "Export for distribution outside of the appstore.") var distribution = false

  /// Scheme selection supplied on the command line.
  @OptionGroup() var scheme: SchemeOption

  /// Target platform supplied on the command line.
  @OptionGroup() var platform: PlatformOption

  /// Shared workspace and diagnostic flags for this command.
  @OptionGroup() var options: CommonOptions

  /// Describes the `export` command for ArgumentParser.
  static var configuration: CommandConfiguration {
    CommandConfiguration(
      commandName: "export",
      abstract: "Export an executable from the output of the archive command."
    )
  }

  /// Resolves command options and exports the release archive.
  func run() async throws {
    let engine = try await ReleaseEngine(
      options: options,
      scheme: scheme,
      platform: platform
    )

    try await Self.export(engine: engine, distribution: distribution)
  }

  /// Writes distribution options and exports the configured Xcode archive.
  static func export(engine: ReleaseEngine, distribution: Bool = false) async throws {
    engine.log(
      "Generating export options for \(distribution ? "direct" : "appstore") distribution.")
    do {
      let exportOptions = [
        "iCloudContainerEnvironment": "Production",
        "signingStyle": "automatic",
        "method": distribution ? "developer-id" : "app-store-connect",
      ]
      let data = try PropertyListSerialization.data(
        fromPropertyList: exportOptions, format: .xml, options: 0)
      try data.write(to: engine.exportOptionsURL)
    } catch {
      throw Error.writingOptionsFailed(error)
    }

    engine.log("Exporting \(engine.scheme)...")
    let xcode = XCodeBuildRunner(engine: engine)
    try? FileManager.default.removeItem(at: engine.exportURL)
    let result = xcode.run([
      "-exportArchive", "-archivePath", engine.archiveURL.path, "-exportPath",
      engine.exportURL.path, "-exportOptionsPlist", engine.exportOptionsURL.path,
      "-allowProvisioningUpdates",
    ])

    try await result.throwIfFailed(Error.exportFailed)
    engine.log("Exported \(engine.scheme).")
  }
}

extension ExportCommand {
  /// Errors emitted while exporting the archive.
  enum Error: Swift.Error, LocalizedError {
    /// Writing the export options file failed.
    case writingOptionsFailed(any Swift.Error)

    /// Exporting the archive failed.
    case exportFailed

    /// A user-facing description of the failure.
    var errorDescription: String? {
      switch self {
        case .exportFailed: return "Exporting failed."
        case .writingOptionsFailed(let error):
          return "Writing export options file failed.\n\(error.localizedDescription)"
      }
    }
  }
}
