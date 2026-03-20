import ArgumentParser
import Foundation
import Testing

@testable import ReleaseTools

struct ConfigTests {

  @Test func usesXDGConfigHomeForGlobalRoot() throws {
    let root = try makeTempDirectory()
    let home = try makeTempDirectory()
    let xdg = try makeTempDirectory()

    let paths = RTConfigPaths(
      rootURL: root,
      homeURL: home,
      environment: ["XDG_CONFIG_HOME": xdg.path]
    )

    #expect(paths.globalDirectoryURL.path == xdg.appendingPathComponent("rt").path)
  }

  @Test func resolvesConfigWithExpectedPrecedence() async throws {
    let root = try makeTempDirectory()
    let home = try makeTempDirectory()
    let paths = RTConfigPaths(rootURL: root, homeURL: home, environment: [:])

    try writeConfig(
      RTConfigDocument(
        defaults: .init(scheme: "Global"),
        settings: BasicSettings(
          keychain: "/global/keychain",
          apiKey: "global-base-key",
          apiIssuer: "global-base-issuer"
        )
      ),
      to: paths.baseURL(root: paths.globalDirectoryURL)
    )

    try writeConfig(
      RTConfigDocument(
        settings: BasicSettings(apiKey: "project-base-key")
      ),
      to: paths.baseURL(root: paths.projectDirectoryURL)
    )

    try writeConfig(
      RTConfigDocument(
        defaults: .init(scheme: "Project"),
        settings: BasicSettings(apiIssuer: "project-local-issuer")
      ),
      to: paths.baseURL(root: paths.projectLocalDirectoryURL)
    )

    try writeConfig(
      RTConfigDocument(
        settings: BasicSettings(apiKey: "project-scheme-key")
      ),
      to: paths.schemeURL(root: paths.projectDirectoryURL, scheme: "App")!
    )

    try writeConfig(
      RTConfigDocument(
        settings: BasicSettings(apiKey: "project-platform-key")
      ),
      to: paths.platformURL(root: paths.projectDirectoryURL, platform: "iOS")!
    )

    try writeConfig(
      RTConfigDocument(
        settings: BasicSettings(apiKey: "project-local-scoped-key")
      ),
      to: paths.scopedURL(root: paths.projectLocalDirectoryURL, scheme: "App", platform: "iOS")!
    )

    let defaultReader = try await RTConfigReader(paths: paths, scheme: nil, platform: "iOS")
    #expect(defaultReader.defaultScheme == "Project")

    let reader = try await RTConfigReader(paths: paths, scheme: "App", platform: "iOS")
    let settings = reader.settings

    #expect(settings.apiKey == "project-local-scoped-key")
    #expect(settings.apiIssuer == "project-local-issuer")
    #expect(settings.keychain == "/global/keychain")
  }

  @Test func migratesLegacyProjectFilesIntoDotRTDirectory() throws {
    let repo = try makeTempDirectory()
    try "# Existing ignore rules\n".write(
      to: repo.appendingPathComponent(".gitignore"),
      atomically: true,
      encoding: .utf8
    )

    try """
      {
        "defaultScheme": "Stack",
        "settings": {
          "*": {
            "apiKey": "base-key"
          },
          "iOS": {
            "apiIssuer": "platform-issuer"
          },
          "Watch": {
            "keychain": "watch-keychain"
          },
          "Watch.iOS": {
            "apiKey": "scoped-key"
          }
        }
      }
      """.write(
        to: repo.appendingPathComponent(".rt.json"),
        atomically: true,
        encoding: .utf8
      )

    try """
      {
        "settings": {
          "*": {
            "apiIssuer": "local-issuer"
          }
        }
      }
      """.write(
        to: repo.appendingPathComponent(".rt.local.json"),
        atomically: true,
        encoding: .utf8
      )

    let paths = RTConfigPaths(rootURL: repo)
    try RTLegacyConfigMigrator(paths: paths).migrateIfNeeded()

    #expect(!FileManager.default.fileExists(atPath: paths.legacyProjectConfigURL.path))
    #expect(!FileManager.default.fileExists(atPath: paths.legacyProjectLocalConfigURL.path))

    let base = try loadConfig(at: paths.baseURL(root: paths.projectDirectoryURL))
    #expect(base.defaults?.scheme == "Stack")
    #expect(base.settings?.apiKey == "base-key")

    let platform = try loadConfig(at: paths.platformURL(root: paths.projectDirectoryURL, platform: "iOS")!)
    #expect(platform.settings?.apiIssuer == "platform-issuer")

    let scheme = try loadConfig(at: paths.schemeURL(root: paths.projectDirectoryURL, scheme: "Watch")!)
    #expect(scheme.settings?.keychain == "watch-keychain")

    let scoped = try loadConfig(
      at: paths.scopedURL(root: paths.projectDirectoryURL, scheme: "Watch", platform: "iOS")!
    )
    #expect(scoped.settings?.apiKey == "scoped-key")

    let localBase = try loadConfig(at: paths.baseURL(root: paths.projectLocalDirectoryURL))
    #expect(localBase.settings?.apiIssuer == "local-issuer")

    let gitIgnore = try String(contentsOf: paths.gitIgnoreURL, encoding: .utf8)
    #expect(gitIgnore.contains(".rt/local/"))
  }

  @Test func releaseEngineMigratesLegacyConfigAndResolvesSchemeSettings() async throws {
    let repo = try await TestRepo()
    let workspaceURL = repo.url.appendingPathComponent("Stack.xcworkspace")
    try FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)

    try """
      {
        "defaultScheme": "Stack",
        "settings": {
          "*": {
            "apiKey": "base-key",
            "apiIssuer": "base-issuer"
          },
          "Stack": {
            "apiKey": "scheme-key",
            "apiIssuer": "scheme-issuer"
          }
        }
      }
      """.write(
        to: repo.url.appendingPathComponent(".rt.json"),
        atomically: true,
        encoding: .utf8
      )

    let options = try CommonOptions.parse([])
    let scheme = try SchemeOption.parse([])
    let engine = try await ReleaseEngine(
      root: repo.url,
      options: options,
      command: ArchiveCommand.configuration,
      scheme: scheme
    )

    #expect(engine.scheme == "Stack")
    #expect(engine.getSettings().apiKey == "scheme-key")
    #expect(engine.getSettings().apiIssuer == "scheme-issuer")
    #expect(FileManager.default.fileExists(atPath: repo.url.appendingPathComponent(".rt/config.json").path))
    #expect(!FileManager.default.fileExists(atPath: repo.url.appendingPathComponent(".rt.json").path))
  }

  private func makeTempDirectory() throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("ReleaseToolsConfigTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  private func writeConfig(_ config: RTConfigDocument, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(config)
    try data.write(to: url)
  }

  private func loadConfig(at url: URL) throws -> RTConfigDocument {
    let data = try Data(contentsOf: url)
    let decoder = JSONDecoder()
    return try decoder.decode(RTConfigDocument.self, from: data)
  }
}
