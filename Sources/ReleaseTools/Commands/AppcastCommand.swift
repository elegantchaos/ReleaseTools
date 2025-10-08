// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 18/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Runner

enum GenerationError: Error, CustomStringConvertible {
  case generatedKeys(_ name: String)

  public var description: String {
    switch self {
      case .generatedKeys(let name):
        return """
          The appcast private key was missing, so we've generated one.
          Open the keychain, rename the key `Imported Private Key` as `\(name)`, then try running this command again.
          """
    }
  }
}
enum AppcastError: LocalizedError {
  case buildAppcastGeneratorFailed(Runner.Session)
  case appcastGeneratorFailed(Runner.Session)
  case keyGenerationFailed(Runner.Session)
  case keyImportFailed(Runner.Session)

  var errorDescription: String? {
    get async {
      switch self {
        case .buildAppcastGeneratorFailed(let session):
          return "Failed to build the generate_appcast tool.\n\n\(await session.stderr.string)"
        case .appcastGeneratorFailed(let session):
          return "Failed to generate the appcast.\n\n\(await session.stderr.string)"
        case .keyGenerationFailed(let session):
          return "Failed to generate appcast keys.\n\n\(await session.stderr.string)"
        case .keyImportFailed(let session):
          return "Failed to import appcast keys.\n\n\(await session.stderr.string)"
      }
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
      keychain ?? parsed.getSettings().keychain
      ?? ("~/Library/Keychains/login.keychain" as NSString).expandingTildeInPath

    parsed.log("Rebuilding appcast.")
    let fm = FileManager.default
    let rootURL = URL(fileURLWithPath: fm.currentDirectoryPath)
    let buildURL = rootURL.appendingPathComponent(".build")
    let result = xcode.run([
      "build", "-workspace", parsed.workspace, "-scheme", "generate_appcast",
      "BUILD_DIR=\(buildURL.path)",
    ])
    let buildState = await result.waitUntilExit()
    if case .failed = buildState {
      throw AppcastError.buildAppcastGeneratorFailed(result)
    }

    let workspaceName = URL(fileURLWithPath: parsed.workspace).deletingPathExtension()
      .lastPathComponent
    let keyName = "\(workspaceName) Sparkle Key"

    let generator = Runner(for: URL(fileURLWithPath: ".build/Release/generate_appcast"))
    let genResult = generator.run(["-n", keyName, "-k", keyChainPath, updates.path])

    for await state in genResult.state {
      if state != .succeeded {
        let output = await genResult.stdout.string
        if !output.contains("Unable to load DSA private key") {
          throw AppcastError.appcastGeneratorFailed(genResult)
        }
      }

      parsed.log("Could not find Sparkle key - generating one.")

      let keygen = Runner(for: URL(fileURLWithPath: "Dependencies/Sparkle/bin/generate_keys"))
      let keygenResult = keygen.run([])
      let keygenState = await keygenResult.waitUntilExit()
      if case .failed = keygenState {
        throw AppcastError.keyGenerationFailed(keygenResult)
      }

      parsed.log("Importing Key.")

      let security = Runner(for: URL(fileURLWithPath: "/usr/bin/security"))
      let importResult = security.run([
        "import", "dsa_priv.pem", "-a", "labl", "\(parsed.scheme) Sparkle Key",
      ])
      let importState = await importResult.waitUntilExit()
      if case .failed = importState {
        throw AppcastError.keyImportFailed(importResult)
      }

      parsed.log("Moving Public Key.")

      try? fm.moveItem(
        at: rootURL.appendingPathComponent("dsa_pub.pem"),
        to: rootURL.appendingPathComponent("Sources").appendingPathComponent(parsed.scheme)
          .appendingPathComponent("Resources").appendingPathComponent("dsa_pub.pem"))

      parsed.log("Deleting Private Key.")

      try? fm.removeItem(at: rootURL.appendingPathComponent("dsa_priv.pem"))

      throw GenerationError.generatedKeys(keyName)
    }

    try? fm.removeItem(at: updates.url.appendingPathComponent(".tmp"))
  }
}
