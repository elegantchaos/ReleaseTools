// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 20/03/26.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

struct RTLegacyConfigMigrator {
  private enum SettingsSchema {
    case canonical
    case legacy
  }

  private struct LegacyConfig: Decodable {
    let defaultScheme: String?
    let settings: [String: BasicSettings]
  }

  private enum LegacySelector {
    case base
    case platform(String)
    case scheme(String)
    case schemePlatform(String, String)
  }

  private static let knownPlatforms: Set<String> = ["macOS", "iOS", "tvOS", "watchOS"]

  let paths: RTConfigPaths
  let fileManager: FileManager

  init(paths: RTConfigPaths, fileManager: FileManager = .default) {
    self.paths = paths
    self.fileManager = fileManager
  }

  func migrateIfNeeded() throws {
    let legacyBaseExists = fileManager.fileExists(atPath: paths.legacyProjectConfigURL.path)
    let legacyLocalExists = fileManager.fileExists(atPath: paths.legacyProjectLocalConfigURL.path)

    guard legacyBaseExists || legacyLocalExists else {
      return
    }

    do {
      if legacyBaseExists && !hasCanonicalConfig(in: paths.projectDirectoryURL) {
        let legacyConfig = try loadLegacyConfig(from: paths.legacyProjectConfigURL)
        try writeMigratedDocuments(for: legacyConfig, local: false)
      }

      if legacyLocalExists && !hasCanonicalConfig(in: paths.projectLocalDirectoryURL) {
        let legacyConfig = try loadLegacyConfig(from: paths.legacyProjectLocalConfigURL)
        try writeMigratedDocuments(for: legacyConfig, local: true)
      }

      if legacyLocalExists {
        try updateGitIgnore()
      }

      if legacyBaseExists && hasCanonicalConfig(in: paths.projectDirectoryURL) {
        try fileManager.removeItem(at: paths.legacyProjectConfigURL)
      }

      if legacyLocalExists && hasCanonicalConfig(in: paths.projectLocalDirectoryURL) {
        try fileManager.removeItem(at: paths.legacyProjectLocalConfigURL)
      }
    } catch let error as RTConfigError {
      throw error
    } catch {
      throw RTConfigError.failedToMigrate(paths.projectDirectoryURL, error)
    }
  }

  private func loadLegacyConfig(from url: URL) throws -> LegacyConfig {
    do {
      let data = try Data(contentsOf: url)

      if let object = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
        let settingsSchema = schemaForSettings(in: object)
        let usesLegacySchema = object["defaultScheme"] != nil || settingsSchema == .legacy
        let usesCanonicalSchema =
          object["defaults"] != nil
          || object["platforms"] != nil
          || object["schemes"] != nil
          || settingsSchema == .canonical

        if usesCanonicalSchema {
          throw RTConfigError.mixedLegacyAndCanonicalSchema(url)
        }

        if !usesLegacySchema {
          throw RTConfigError.invalidLegacyConfigurationFile(
            url,
            CocoaError(.propertyListReadCorrupt)
          )
        }
      }

      let decoder = JSONDecoder()
      return try decoder.decode(LegacyConfig.self, from: data)
    } catch let error as RTConfigError {
      throw error
    } catch {
      throw RTConfigError.invalidLegacyConfigurationFile(url, error)
    }
  }

  private func writeMigratedDocuments(for legacy: LegacyConfig, local: Bool) throws {
    let root = local ? paths.projectLocalDirectoryURL : paths.projectDirectoryURL
    var documents: [URL: RTConfigDocument] = [:]

    if let defaultScheme = legacy.defaultScheme {
      var document = documents[paths.baseURL(root: root)] ?? RTConfigDocument()
      document.defaults = RTConfigDocument.Defaults(scheme: defaultScheme)
      documents[paths.baseURL(root: root)] = document
    }

    for (selector, settings) in legacy.settings {
      let targetURL = targetURL(for: selector, root: root)
      var document = documents[targetURL] ?? RTConfigDocument()
      document.settings = settings
      documents[targetURL] = document
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    for (url, document) in documents where !document.isEmpty {
      do {
        try fileManager.createDirectory(
          at: url.deletingLastPathComponent(),
          withIntermediateDirectories: true
        )
        let data = try encoder.encode(document)
        try data.write(to: url, options: .atomic)
      } catch {
        throw RTConfigError.failedToMigrate(url, error)
      }
    }
  }

  private func hasCanonicalConfig(in root: URL) -> Bool {
    let baseURL = paths.baseURL(root: root)
    if fileManager.fileExists(atPath: baseURL.path) {
      return true
    }

    let excludedPrefix: String? =
      root == paths.projectDirectoryURL ? paths.projectLocalDirectoryURL.path + "/" : nil

    guard let enumerator = fileManager.enumerator(
      at: root,
      includingPropertiesForKeys: [.isRegularFileKey],
      options: [.skipsHiddenFiles]
    ) else {
      return false
    }

    for case let url as URL in enumerator where url.pathExtension == "json" {
      if let excludedPrefix, url.path.hasPrefix(excludedPrefix) {
        continue
      }

      return true
    }

    return false
  }

  private func schemaForSettings(in object: [String: Any]) -> SettingsSchema? {
    guard let settings = object["settings"] as? [String: Any] else {
      return nil
    }

    if settings.values.contains(where: { $0 is [String: Any] }) {
      return .legacy
    }

    return .canonical
  }

  private func targetURL(for selector: String, root: URL) -> URL {
    switch classify(selector: selector) {
      case .base:
        return paths.baseURL(root: root)
      case .platform(let platform):
        return paths.platformURL(root: root, platform: platform)!
      case .scheme(let scheme):
        return paths.schemeURL(root: root, scheme: scheme)!
      case .schemePlatform(let scheme, let platform):
        return paths.scopedURL(root: root, scheme: scheme, platform: platform)!
    }
  }

  private func classify(selector: String) -> LegacySelector {
    if selector == "*" {
      return .base
    }

    let components = selector.split(separator: ".").map(String.init)
    if let last = components.last, Self.knownPlatforms.contains(last), components.count > 1 {
      let scheme = components.dropLast().joined(separator: ".")
      return .schemePlatform(scheme, last)
    }

    if Self.knownPlatforms.contains(selector) {
      return .platform(selector)
    }

    return .scheme(selector)
  }

  private func updateGitIgnore() throws {
    let gitIgnoreURL = paths.gitIgnoreURL
    let ignoreRule = ".rt/local/"

    do {
      let existing = (try? String(contentsOf: gitIgnoreURL, encoding: .utf8)) ?? ""
      let existingRules = Set(existing.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) })
      guard !existingRules.contains(ignoreRule), !existingRules.contains(".rt/local") else {
        return
      }

      var updated = existing
      if !updated.isEmpty && !updated.hasSuffix("\n") {
        updated.append("\n")
      }
      updated.append(ignoreRule)
      updated.append("\n")
      try updated.write(to: gitIgnoreURL, atomically: true, encoding: .utf8)
    } catch {
      throw RTConfigError.failedToUpdateGitIgnore(gitIgnoreURL, error)
    }
  }
}
