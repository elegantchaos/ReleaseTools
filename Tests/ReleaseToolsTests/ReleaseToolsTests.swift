import Foundation
import ReleaseTools
import Testing

@Suite struct WorkspaceSettingsTests {
  @Test func testMinimalWorkspaceSettings() async throws {
    let json = """
      {
        "defaultScheme": null,
        "settings": {
          "user": {},
          "keychain": {},
          "offset": {},
          "increment-tag": {},
          "api-key": {},
          "api-issuer": {}
        }
      }
      """

    let decoder = JSONDecoder()
    let decoded: WorkspaceSettings = try decoder.decode(WorkspaceSettings.self, from: json.data(using: .utf8)!)
    #expect(decoded.defaultScheme == nil)
  }

  @Test func testEmptyJSON() async throws {
    let json = ""

    let decoder = JSONDecoder()
    #expect(throws: DecodingError.self) {
      _ = try decoder.decode(WorkspaceSettings.self, from: json.data(using: .utf8)!)
    }
  }

  @Test func testEmptyWorkspaceSettings() async throws {
    let json = "{ }"

    let decoder = JSONDecoder()
    #expect(throws: DecodingError.self) {
      _ = try decoder.decode(WorkspaceSettings.self, from: json.data(using: .utf8)!)
    }
  }

  @Test func testJustScheme() async throws {
    let json = """
      {
        "defaultScheme": "testScheme",
      }
      """
    let decoder = JSONDecoder()
    let decoded: WorkspaceSettings = try decoder.decode(WorkspaceSettings.self, from: json.data(using: .utf8)!)
    #expect(decoded.defaultScheme == "testScheme")
  }

  @Test func testBasicSettingScheme() async throws {
    let json = """
      {
        "settings" : {
          "user": "sam",
        }
      }
      """
    let decoder = JSONDecoder()
    let decoded: WorkspaceSettings = try decoder.decode(WorkspaceSettings.self, from: json.data(using: .utf8)!)
    #expect(decoded.settings?.user["*"] == "sam")
  }

  @Test func testMultipleSettingScheme() async throws {
    let json = """
      {
        "settings" : {
          "user": {
            "*": "sam",
            "specific": "other"
          }
        }
      }
      """
    let decoder = JSONDecoder()
    let decoded: WorkspaceSettings = try decoder.decode(WorkspaceSettings.self, from: json.data(using: .utf8)!)
    #expect(decoded.settings?.user["*"] == "sam")
    #expect(decoded.settings?.user["specific"] == "other")
  }
}
