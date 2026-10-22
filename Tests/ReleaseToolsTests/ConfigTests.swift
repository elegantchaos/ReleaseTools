// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 21/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Testing

@testable import ReleaseTools

/// Checks canonical configuration discovery, precedence, and engine initialization.
struct ConfigTests {
  /// Global configuration honors the supplied XDG root.
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

  /// Specific local overrides win while unspecified fields inherit broader defaults.
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
      to: try #require(paths.schemeURL(root: paths.projectDirectoryURL, scheme: "App"))
    )

    try writeConfig(
      RTConfigDocument(
        settings: BasicSettings(apiKey: "project-platform-key")
      ),
      to: try #require(paths.platformURL(root: paths.projectDirectoryURL, platform: "iOS"))
    )

    try writeConfig(
      RTConfigDocument(
        settings: BasicSettings(apiKey: "project-local-scoped-key")
      ),
      to: try #require(paths.scopedURL(root: paths.projectLocalDirectoryURL, scheme: "App", platform: "iOS"))
    )

    let defaultReader = try await RTConfigReader(paths: paths, scheme: nil, platform: "iOS")
    #expect(defaultReader.defaultScheme == "Project")

    let reader = try await RTConfigReader(paths: paths, scheme: "App", platform: "iOS")
    let settings = reader.settings

    #expect(settings.apiKey == "project-local-scoped-key")
    #expect(settings.apiIssuer == "project-local-issuer")
    #expect(settings.keychain == "/global/keychain")
  }

  /// Engine initialization reads canonical settings without modifying unrelated files.
  @Test func ignoresLegacyConfigurationFiles() async throws {
    let repo = try await TestRepo()
    let legacy = repo.url.appending(path: ".rt.json")
    let local = repo.url.appending(path: ".rt.local.json")
    let contents = "{\"defaultScheme\":\"Ignored\",\"settings\":{\"*\":{\"apiKey\":\"ignored\"}}}"
    try contents.write(to: legacy, atomically: true, encoding: .utf8)
    try contents.write(to: local, atomically: true, encoding: .utf8)
    let options = try CommonOptions.parse([])
    let engine = try await ReleaseEngine(root: repo.url, options: options)

    #expect(engine.configReader.defaultScheme == nil)
    #expect(engine.getSettings().apiKey == nil)
    #expect(try String(contentsOf: legacy, encoding: .utf8) == contents)
    #expect(try String(contentsOf: local, encoding: .utf8) == contents)
    #expect(FileManager.default.fileExists(atPath: repo.url.appending(path: ".rt").path) == false)
    #expect(FileManager.default.fileExists(atPath: repo.url.appending(path: ".gitignore").path) == false)
  }

  /// Scheme-specific canonical settings override the base document during engine initialization.
  @Test func releaseEngineResolvesCanonicalSchemeSettings() async throws {
    let repo = try await TestRepo()
    let workspace = repo.url.appending(path: "Stack.xcworkspace")
    try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
    let paths = RTConfigPaths(rootURL: repo.url)
    try writeConfig(
      RTConfigDocument(defaults: .init(scheme: "Stack"), settings: .init(apiKey: "base-key", apiIssuer: "base-issuer")),
      to: paths.baseURL(root: paths.projectDirectoryURL)
    )
    try writeConfig(
      RTConfigDocument(settings: .init(apiKey: "scheme-key", apiIssuer: "scheme-issuer")),
      to: try #require(paths.schemeURL(root: paths.projectDirectoryURL, scheme: "Stack"))
    )
    let options = try CommonOptions.parse([])
    let scheme = try SchemeOption.parse([])
    let engine = try await ReleaseEngine(root: repo.url, options: options, scheme: scheme)

    #expect(engine.scheme == "Stack")
    #expect(engine.getSettings().apiKey == "scheme-key")
    #expect(engine.getSettings().apiIssuer == "scheme-issuer")
  }

  /// Creates an isolated directory for configuration fixtures.
  private func makeTempDirectory() throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("ReleaseToolsConfigTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  /// Writes a canonical JSON fixture, creating its parent directories.
  private func writeConfig(_ config: RTConfigDocument, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(config)
    try data.write(to: url)
  }
}
