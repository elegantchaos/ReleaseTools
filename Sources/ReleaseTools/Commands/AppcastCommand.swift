// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 18/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Runner

enum AppcastError: Error, CustomStringConvertible {
  case buildAppcastGeneratorFailed(_ output: String)
  case appcastGeneratorFailed(_ result: Runner.Result)
  case keyGenerationFailed(_ result: Runner.Result)
  case keyImportFailed(_ result: Runner.Result)
  case generatedKeys(_ name: String)

  public var description: String {
    switch self {
    case .buildAppcastGeneratorFailed(let output):
      return "Failed to build the generate_appcast tool.\n\(output)"
    case .appcastGeneratorFailed(let result): return "Failed to generate the appcast.\n\(result)"
    case .keyGenerationFailed(let result): return "Failed to generate appcast keys.\n\(result)"
    case .keyImportFailed(let result): return "Failed to import appcast keys.\n\(result)"
    case .generatedKeys(let name):
      return """
        The appcast private key was missing, so we've generated one.
        Open the keychain, rename the key `Imported Private Key` as `\(name)`, then try running this command again.
        """
    }
  }
}

struct AppcastCommand: ParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "appcast",
    abstract: "Update the Sparkle appcast to include the zip created by the compress command."
  )

  @Option(
    help: "Path the to the keychain to get the appcast key from. Defaults to the login keychain.")
  var keychain: String?
  @OptionGroup() var scheme: SchemeOption
  @OptionGroup() var platform: PlatformOption
  @OptionGroup() var updates: UpdatesOption
  @OptionGroup() var options: CommonOptions

  func run() throws {
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
    let result = try xcode.run(arguments: [
      "build", "-workspace", parsed.workspace, "-scheme", "generate_appcast",
      "BUILD_DIR=\(buildURL.path)",
    ])
    if result.status != 0 {
      throw AppcastError.buildAppcastGeneratorFailed(result.stderr)
    }

    let workspaceName = URL(fileURLWithPath: parsed.workspace).deletingPathExtension()
      .lastPathComponent
    let keyName = "\(workspaceName) Sparkle Key"

    let generator = Runner(for: URL(fileURLWithPath: ".build/Release/generate_appcast"))
    let genResult = try generator.sync(arguments: ["-n", keyName, "-k", keyChainPath, updates.path])
    if genResult.status != 0 {
      if !genResult.stdout.contains("Unable to load DSA private key") {
        throw AppcastError.appcastGeneratorFailed(genResult)
      }

      parsed.log("Could not find Sparkle key - generating one.")

      let keygen = Runner(for: URL(fileURLWithPath: "Dependencies/Sparkle/bin/generate_keys"))
      let keygenResult = try keygen.sync(arguments: [])
      if keygenResult.status != 0 {
        throw AppcastError.keyGenerationFailed(keygenResult)
      }

      parsed.log("Importing Key.")

      let security = Runner(for: URL(fileURLWithPath: "/usr/bin/security"))
      let importResult = try security.sync(arguments: [
        "import", "dsa_priv.pem", "-a", "labl", "\(parsed.scheme) Sparkle Key",
      ])
      if importResult.status != 0 {
        throw AppcastError.keyImportFailed(importResult)
      }

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
