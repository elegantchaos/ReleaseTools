// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 11/08/25.
//  All code (c) 2025 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Runner

struct MigrateCommand: AsyncParsableCommand {
  static var configuration: CommandConfiguration {
    CommandConfiguration(
      commandName: "migrate",
      abstract: "Migrate settings to a `.rt`. file."
    )
  }

  @OptionGroup() var scheme: SchemeOption
  @OptionGroup() var user: UserOption
  @OptionGroup() var platform: PlatformOption
  @OptionGroup() var options: CommonOptions

  func run() async throws {

    let parsed = try OptionParser(
      requires: [.archive],
      options: options,
      command: Self.configuration,
      scheme: scheme,
      platform: platform
    )

    let keys = [
      "keychain",
      "offset",
      "increment-tag",
      "user",
      "api-key",
      "api-issuer",
      "scheme",
    ]

    let settingsURL = URL(filePath: ".rt.json")!
    var settings = WorkspaceSettings(defaultScheme: parsed.scheme, schemes: [:])

    if let existingData = try? Data(contentsOf: settingsURL) {
      let decoder = JSONDecoder()
      do {
        settings = try decoder.decode(WorkspaceSettings.self, from: existingData)
      } catch {
        parsed.log("Error decoding existing settings: \(error)")
      }
    }

    for (key, value) in UserDefaults.standard.dictionaryRepresentation() {
      let components = key.split(separator: ".")
      if let k = components.first {
        // guard keys.contains(String(k)) else { continue }
        print(k, key, value)
      }
    }

    // // Write the settings to a .rt file.
    // let settingsFileURL = parsed.workspaceURL.appendingPathComponent(".rt")
    // let encoder = JSONEncoder()
    // encoder.outputFormatting = .prettyPrinted

    // let data = try encoder.encode(workspaceSettings)
    // try data.write(to: settingsFileURL)

    parsed.log("Migration complete. Settings saved to \(settingsURL.path).")
  }
}

struct WorkspaceSettings: Codable {
  let defaultScheme: String?
  let schemes: [String: SchemeSettings]
}

struct SchemeSettings: Codable {
  var user: String?
  var keychain: String?
  var offset: Int?
  var incrementTag: Bool = false
  var apiKey: String?
  var apiIssuer: String?

  init(user: String? = nil, keychain: String? = nil, offset: Int? = nil, incrementTag: Bool = false, apiKey: String? = nil, apiIssuer: String? = nil) {
    self.user = user
    self.keychain = keychain
    self.offset = offset
    self.incrementTag = incrementTag
    self.apiKey = apiKey
    self.apiIssuer = apiIssuer
  }
}
