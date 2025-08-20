// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 12/08/25.
//  All code (c) 2025 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

public struct WorkspaceSettings: Codable {
  /// Default scheme to read settings from.
  public var defaultScheme: String?

  /// Scheme-specific settings.
  public var settings: BasicSettings?

  init() {
    self.defaultScheme = nil
    self.settings = BasicSettings()
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

  /// Migrate settings for this workspace/scheme/platform from UserDefaults to the workspace settings.
  mutating func migrateSettings(workspace: String, scheme: String, platform: String) -> Bool {
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

          var settings = self.settings ?? BasicSettings()
          if settings.migrateSetting(key: String(property), value: String(describing: value), migratedKey: migratedKey) == true {
            print("migrated setting for scheme \(migratedKey): \(property) = \(value)")
            defaults.removeObject(forKey: key)
            migrated = true
            self.settings = settings
          }
        }
      }
    }
    return migrated
  }
}

public struct BasicSettings: Codable {
  public var user: [String: String]
  public var keychain: [String: String]
  public var offset: [String: Int]
  public var incrementTag: [String: Bool]
  public var apiKey: [String: String]
  public var apiIssuer: [String: String]

  enum CodingKeys: String, CodingKey {
    case user
    case keychain
    case offset
    case incrementTag = "increment-tag"
    case apiKey = "api-key"
    case apiIssuer = "api-issuer"
  }

  init() {
    self.user = [:]
    self.keychain = [:]
    self.offset = [:]
    self.incrementTag = [:]
    self.apiKey = [:]
    self.apiIssuer = [:]
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    user = try Self.decodeAsDictionary(String.self, forKey: .user, container: container)
    keychain = try Self.decodeAsDictionary(String.self, forKey: .keychain, container: container)
    offset = try Self.decodeAsDictionary(Int.self, forKey: .offset, container: container)
    incrementTag = try Self.decodeAsDictionary(Bool.self, forKey: .incrementTag, container: container)
    apiKey = try Self.decodeAsDictionary(String.self, forKey: .apiKey, container: container)
    apiIssuer = try Self.decodeAsDictionary(String.self, forKey: .apiIssuer, container: container)
  }

  private static func decodeAsDictionary<T: Decodable>(_ type: T.Type, forKey key: CodingKeys, container: KeyedDecodingContainer<CodingKeys>) throws -> [String: T] {
    if let dictionary = try? container.decodeIfPresent([String: T].self, forKey: key) {
      return dictionary
    } else if let item = try container.decodeIfPresent(T.self, forKey: key) {
      return ["*": item]
    } else {
      return [:]
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(user, forKey: .user)
    try container.encodeIfPresent(keychain, forKey: .keychain)
    try container.encodeIfPresent(offset, forKey: .offset)
    try container.encodeIfPresent(incrementTag, forKey: .incrementTag)
    try container.encodeIfPresent(apiKey, forKey: .apiKey)
    try container.encodeIfPresent(apiIssuer, forKey: .apiIssuer)
  }

  mutating func migrateSetting(key: String, value: String, migratedKey: String) -> Bool {
    var migrated = false
    switch key {
      case "user":
        if user[migratedKey] == nil {
          user[migratedKey] = value
          migrated = true
        }
      case "keychain":
        if keychain[migratedKey] == nil {
          keychain[migratedKey] = value
          migrated = true
        }
      case "offset":
        if offset[migratedKey] == nil {
          offset[migratedKey] = Int(value)
          migrated = true
        }
      case "increment-tag":
        if incrementTag[migratedKey] == nil {
          incrementTag[migratedKey] = Bool(value)
          migrated = true
        }
      case "api-key":
        if apiKey[migratedKey] == nil {
          apiKey[migratedKey] = value
          migrated = true
        }
      case "api-issuer":
        if apiIssuer[migratedKey] == nil {
          apiIssuer[migratedKey] = value
          migrated = true
        }
      default:
        break
    }
    return migrated
  }
}
