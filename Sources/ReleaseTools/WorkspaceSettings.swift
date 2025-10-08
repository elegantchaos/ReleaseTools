// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 12/08/25.
//  All code (c) 2025 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

public class WorkspaceSettings: Codable {
  /// Default scheme to read settings from.
  public var defaultScheme: String?

  /// Scheme-specific settings.
  private var settings: [String: BasicSettings]

  public init() {
    self.defaultScheme = nil
    self.settings = [:]
  }

  public static func load(url: URL) throws -> WorkspaceSettings {
    let data = try Data(contentsOf: url)
    let decoder = JSONDecoder()
    return try decoder.decode(WorkspaceSettings.self, from: data)
  }

  public func write(to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    let data = try encoder.encode(self)
    try data.write(to: url)
  }

  public func settings(scheme explicitScheme: String? = nil, platform: String? = nil) -> BasicSettings {
    let merged = settings["*"] ?? BasicSettings()
    if let scheme = explicitScheme ?? defaultScheme {
      merged.merge(with: settings[scheme])
      if let platform {
        merged.merge(with: settings[platform])
        merged.merge(with: settings["\(scheme).\(platform)"])
      }
    }
    return merged
  }

  /// Migrate settings for this workspace/scheme/platform from UserDefaults to the workspace settings.
  public func migrateSettings(workspace: String, scheme: String, platform: String) -> Bool {
    var migrated = false
    let defaults = UserDefaults.standard
    for (key, value) in defaults.dictionaryRepresentation() {
      if key.hasSuffix(workspace) {
        var components = key.split(separator: ".")
        components.removeLast(2)
        if components.count > 1 {
          var migratedKey = String(components[1])
          if migratedKey == "default" {
            migratedKey = "*"
          }
          let property = components[0]
          if components.count > 2 {
            migratedKey += "." + String(components[2])
          }

          let settings = self.settings[migratedKey] ?? BasicSettings()
          if settings.migrateSetting(key: String(property), value: String(describing: value), migratedKey: migratedKey) == true {
            print("migrated setting for scheme \(migratedKey): \(property) = \(value)")
            defaults.removeObject(forKey: key)
            migrated = true
          }
        }
      }
    }
    return migrated
  }
}

public class BasicSettings: Codable {
  public var keychain: String?
  public var apiKey: String?
  public var apiIssuer: String?

  public init() {
  }

  public func merge(with other: BasicSettings?) {
    if let other {
      keychain = other.keychain ?? keychain
      apiKey = other.apiKey ?? apiKey
      apiIssuer = other.apiIssuer ?? apiIssuer
    }
  }

  func migrateSetting(key: String, value: String, migratedKey: String) -> Bool {
    var migrated = false
    switch key {
      case "keychain":
        keychain = value
        migrated = true
      case "offset", "increment-tag", "existing-tag", "explicit-build":
        // Deprecated - no longer used
        migrated = true
      case "api-key":
        apiKey = value
        migrated = true
      case "api-issuer":
        apiIssuer = value
        migrated = true
      default:
        break
    }
    return migrated
  }
}
