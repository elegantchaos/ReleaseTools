import Foundation
import ReleaseTools
import Testing

@Suite struct WorkspaceSettingsTests {
  @Test func testOverrides() async throws {
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
    let decoded = try decoder.decode(WorkspaceSettings.self, from: json.data(using: .utf8)!)
    #expect(decoded.defaultScheme == "Stack")
    #expect(decoded.settings().apiKey == "blah")
    #expect(decoded.settings(scheme: "Watch").apiKey == "wibble")
    #expect(decoded.settings(scheme: "Watch.iOS").apiKey == "jibber")
  }
}
