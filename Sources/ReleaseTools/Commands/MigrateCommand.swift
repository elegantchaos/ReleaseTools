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
      requires: [.workspace],
      options: options,
      command: Self.configuration,
      scheme: scheme,
      platform: platform
    )

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
      if key.hasSuffix(parsed.workspace) {
        var components = key.split(separator: ".")
        if components.count > 1 {
          components.removeLast(2)
          var schemeName = String(components[1])
          if schemeName == "default" {
            schemeName = parsed.scheme
          }
          let property = components[0]
          let platform = (components.count > 2) ? String(components[2]) : "any"
          print("migrated \(platform) setting for scheme \(schemeName): \(property) = \(value)")
          settings.schemes[schemeName, default: SchemeSettings()].platforms[platform, default: RTSettings()].setFromKey(String(property), value: String(describing: value))
        }
      }
    }

    // // Write the settings to a .rt file.
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    let data = try encoder.encode(settings)
    try data.write(to: settingsURL)

    parsed.log("Migration complete. Settings saved to \(settingsURL.path).")
  }
}

struct WorkspaceSettings: Codable {
  /// Default scheme to read settings from.
  var defaultScheme: String?

  /// Scheme-specific settings.
  var schemes: [String: SchemeSettings] = [:]
}

struct SchemeSettings: Codable {
  /// Settings indexed by platform.
  /// Default values are stored in the platform "any".
  var platforms: [String: RTSettings] = [:]
}

struct RTSettings: Codable {
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

  mutating func setFromKey(_ key: String, value: String) {
    switch key {
      case "user":
        self.user = value
      case "keychain":
        self.keychain = value
      case "offset":
        self.offset = Int(value)
      case "increment-tag":
        self.incrementTag = Bool(value) ?? false
      case "api-key":
        self.apiKey = value
      case "api-issuer":
        self.apiIssuer = value
      default:
        break
    }
  }
}
