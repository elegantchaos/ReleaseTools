// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 12/08/25.
//  All code (c) 2025 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

struct WorkspaceSettings: Codable {
  /// Default scheme to read settings from.
  var defaultScheme: String?

  /// Scheme-specific settings.
  var schemes: [String: SchemeSettings] = [:]

  init() {
  }

  init(url: URL) throws {
    let data = try Data(contentsOf: url)
    let decoder = JSONDecoder()
    self = try decoder.decode(WorkspaceSettings.self, from: data)
  }

  func write(to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    let data = try encoder.encode(self)
    try data.write(to: url)
  }

  /// Migrate a setting from UserDefaults to the workspace settings.
  mutating func migrateSetting(parsed: OptionParser, scheme: String, platform: String, key: String, value: String) {
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
          print("migrated setting for scheme \(schemeName): \(property) = \(value) (platform: \(platform))")
          schemes[schemeName, default: SchemeSettings()].platforms[platform, default: BasicSettings()].migrateSetting(key: String(property), value: String(describing: value))
        }
      }
    }
  }
}

struct SchemeSettings: Codable {
  /// Settings indexed by platform.
  /// Default values are stored in the platform "any".
  var platforms: [String: BasicSettings] = [:]
}

struct BasicSettings: Codable {
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

  mutating func migrateSetting(key: String, value: String) {
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
