// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 18/04/2019.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Runner

/// Rebuilds a Sparkle Appcast from the compressed release archive.
struct AppcastCommand: AsyncParsableCommand {
  /// Describes the `appcast` command for ArgumentParser.
  static var configuration: CommandConfiguration {
    CommandConfiguration(
      commandName: "appcast",
      abstract: "Update the Sparkle appcast to include the zip created by the compress command."
    )
  }

  @Option(
    help: "Path the to the keychain to get the appcast key from. Defaults to the login keychain.")
  var keychain: String?
  @OptionGroup() var scheme: SchemeOption
  @OptionGroup() var platform: PlatformOption
  @OptionGroup() var updates: UpdatesOption
  @OptionGroup() var options: CommonOptions

  func run() async throws {
    let engine = try await ReleaseEngine(
      options: options,
      command: Self.configuration,
      scheme: scheme,
      platform: platform
    )

    let xcode = XCodeBuildRunner(engine: engine)

    let keyChainPath =
      keychain ?? engine.getSettings().keychain
      ?? ("~/Library/Keychains/login.keychain" as NSString).expandingTildeInPath

    engine.log("Rebuilding appcast.")
    let fm = FileManager.default
    let rootURL = URL(fileURLWithPath: fm.currentDirectoryPath)
    let buildURL = rootURL.appendingPathComponent(".build")
    let result = xcode.run([
      "build", "-workspace", engine.workspace, "-scheme", "generate_appcast",
      "BUILD_DIR=\(buildURL.path)",
    ])
    try await result.throwIfFailed(Error.buildGeneratorFailed)

    let workspaceName = URL(fileURLWithPath: engine.workspace).deletingPathExtension()
      .lastPathComponent
    let keyName = "\(workspaceName) Sparkle Key"

    let generator = Runner(for: URL(fileURLWithPath: ".build/Release/generate_appcast"))
    let genResult = generator.run(["-n", keyName, "-k", keyChainPath, updates.path])

    for await state in genResult.state {
      if state != .succeeded {
        let output = await genResult.stdout.string
        if !output.contains("Unable to load DSA private key") {
          try await genResult.throwIfFailed(Error.generatingAppcastFailed)
        }
      }

      engine.log("Could not find Sparkle key - generating one.")

      let keygen = Runner(for: URL(fileURLWithPath: "Dependencies/Sparkle/bin/generate_keys"))
      let keygenResult = keygen.run([])
      try await keygenResult.throwIfFailed(Error.generatingKeysFailed)

      engine.log("Importing Key.")

      let security = Runner(for: URL(fileURLWithPath: "/usr/bin/security"))
      let importResult = security.run([
        "import", "dsa_priv.pem", "-a", "labl", "\(engine.scheme) Sparkle Key",
      ])
      try await importResult.throwIfFailed(Error.importingKeysFailed)

      engine.log("Moving Public Key.")

      try? fm.moveItem(
        at: rootURL.appendingPathComponent("dsa_pub.pem"),
        to: rootURL.appendingPathComponent("Sources").appendingPathComponent(engine.scheme)
          .appendingPathComponent("Resources").appendingPathComponent("dsa_pub.pem"))

      engine.log("Deleting Private Key.")

      try? fm.removeItem(at: rootURL.appendingPathComponent("dsa_priv.pem"))

      throw Error.generatedKeys(keyName)
    }

    try? fm.removeItem(at: updates.url.appendingPathComponent(".tmp"))
  }
}

extension AppcastCommand {
  /// Errors emitted while rebuilding the Appcast.
  enum Error: Swift.Error, LocalizedError {
    /// The Appcast key was generated and must be renamed in Keychain Access.
    case generatedKeys(String)

    /// Building `generate_appcast` failed.
    case buildGeneratorFailed
    /// Generating the Appcast failed.
    case generatingAppcastFailed
    /// Generating the Appcast keys failed.
    case generatingKeysFailed
    /// Importing the Appcast keys failed.
    case importingKeysFailed

    /// A user-facing description of the failure.
    var errorDescription: String? {
      switch self {
        case .buildGeneratorFailed: return "Failed to build the generate_appcast tool."
        case .generatingAppcastFailed: return "Failed to generate the appcast."
        case .generatingKeysFailed: return "Failed to generate appcast keys."
        case .importingKeysFailed: return "Failed to import appcast keys."
        case .generatedKeys(let name):
          return """
            The appcast private key was missing, so we've generated one.
            Open the keychain, rename the key `Imported Private Key` as `\(name)`, then try running this command again.
            """
      }
    }
  }
}
