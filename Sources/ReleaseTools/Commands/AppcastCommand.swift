// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 18/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Runner

enum AppcastError: Error, CustomStringConvertible {
  case buildAppcastGeneratorFailed
  case appcastGeneratorFailed
  case keyGenerationFailed
  case keyImportFailed
  case generatedKeys(_ name: String)

  public var description: String {
    switch self {
    case .buildAppcastGeneratorFailed:
      return "Failed to build the generate_appcast tool."
    case .appcastGeneratorFailed: return "Failed to generate the appcast."
    case .keyGenerationFailed: return "Failed to generate appcast keys."
    case .keyImportFailed: return "Failed to import appcast keys."
    case .generatedKeys(let name):
      return """
        The appcast private key was missing, so we've generated one.
        Open the keychain, rename the key `Imported Private Key` as `\(name)`, then try running this command again.
        """
    }
  }
}

struct AppcastCommand: AsyncParsableCommand {
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
    let parsed = try OptionParser(
      options: options,
      command: Self.configuration,
      scheme: scheme,
      platform: platform
    )

    let xcode = XCodeBuildRunner(parsed: parsed)

    let keyChainPath =
      keychain ?? parsed.getDefault(for: "keychain")
      ?? ("~/Library/Keychains/login.keychain" as NSString).expandingTildeInPath

    parsed.log("Rebuilding appcast.")
    let fm = FileManager.default
    let rootURL = URL(fileURLWithPath: fm.currentDirectoryPath)
    let buildURL = rootURL.appendingPathComponent(".build")
    let result = try xcode.run([
      "build", "-workspace", parsed.workspace, "-scheme", "generate_appcast",
      "BUILD_DIR=\(buildURL.path)",
    ])
    try await result.throwIfFailed(AppcastError.buildAppcastGeneratorFailed)

    let workspaceName = URL(fileURLWithPath: parsed.workspace).deletingPathExtension()
      .lastPathComponent
    let keyName = "\(workspaceName) Sparkle Key"

    let generator = Runner(for: URL(fileURLWithPath: ".build/Release/generate_appcast"))
    let genResult = try generator.run(["-n", keyName, "-k", keyChainPath, updates.path])
    for await state in genResult.state {
      if state != .succeeded {
        let output = await String(genResult.stdout)
        if !output.contains("Unable to load DSA private key") {
          throw AppcastError.appcastGeneratorFailed
        }
      }

      parsed.log("Could not find Sparkle key - generating one.")

      let keygen = Runner(for: URL(fileURLWithPath: "Dependencies/Sparkle/bin/generate_keys"))
      let keygenResult = try keygen.run([])
      try await keygenResult.throwIfFailed(AppcastError.keyGenerationFailed)

      parsed.log("Importing Key.")

      let security = Runner(for: URL(fileURLWithPath: "/usr/bin/security"))
      let importResult = try security.run([
        "import", "dsa_priv.pem", "-a", "labl", "\(parsed.scheme) Sparkle Key",
      ])
      try await importResult.throwIfFailed(AppcastError.keyImportFailed)

      parsed.log("Moving Public Key.")

      try? fm.moveItem(
        at: rootURL.appendingPathComponent("dsa_pub.pem"),
        to: rootURL.appendingPathComponent("Sources").appendingPathComponent(parsed.scheme)
          .appendingPathComponent("Resources").appendingPathComponent("dsa_pub.pem"))

      parsed.log("Deleting Private Key.")

      try? fm.removeItem(at: rootURL.appendingPathComponent("dsa_priv.pem"))

      throw AppcastError.generatedKeys(keyName)
    }

    try? fm.removeItem(at: updates.url.appendingPathComponent(".tmp"))
  }
}
