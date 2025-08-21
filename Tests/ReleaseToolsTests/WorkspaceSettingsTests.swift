import Foundation
import ReleaseTools
import Testing

@Suite struct MoreWorkspaceSettingsTests {
  @Test func testExample() async throws {
    let json = """
      {
        "defaultScheme": "Stack",
        "settings": {
          "Stack": {
            "apiKey": "blah",
            "apiProvider": "foo"
          },
          "Watch": {
            "apiKey": "wibble",
            "apiProvider": "bar"
          },
          "Watch.iOS": {
            "apiKey": "jibber",
            "apiProvider": "baz"
          }
        }
      }
      """

    let decoder: JSONDecoder = JSONDecoder()
    let decoded = try decoder.decode(RootSettings.self, from: json.data(using: .utf8)!)
    #expect(decoded.defaultScheme == "Stack")
    #expect(decoded.settings().apiKey == "blah")
    #expect(decoded.settings(scheme: "Watch").apiKey == "wibble")
    #expect(decoded.settings(scheme: "Watch.iOS").apiKey == "jibber")
  }
}

public struct RootSettings: Codable {
  public var defaultScheme: String?
  private var settings: [String: BasicSettings]

  public func settings(scheme explicitScheme: String? = nil, platform: String? = nil) -> BasicSettings {
    var merged = settings["*"] ?? BasicSettings()
    if let scheme = explicitScheme ?? defaultScheme {
      merged.merge(with: settings[scheme])
      if let platform {
        merged.merge(with: settings[platform])
        merged.merge(with: settings["\(scheme).\(platform)"])
      }
    }
    return merged
  }
}

public struct BasicSettings: Codable {
  public var user: String?
  public var keychain: String?
  public var offset: Int?
  public var incrementTag: Bool?
  public var apiKey: String?
  public var apiIssuer: String?

  mutating func merge(with other: BasicSettings?) {
    if let other {
      user = other.user ?? user
      keychain = other.keychain ?? keychain
      offset = other.offset ?? offset
      incrementTag = other.incrementTag ?? incrementTag
      apiKey = other.apiKey ?? apiKey
      apiIssuer = other.apiIssuer ?? apiIssuer
    }
  }
}
