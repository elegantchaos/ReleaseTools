// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 20/03/26.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

struct RTConfigPaths {
  let rootURL: URL
  let homeURL: URL
  let environment: [String: String]

  init(
    rootURL: URL,
    homeURL: URL = FileManager.default.homeDirectoryForCurrentUser,
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) {
    self.rootURL = rootURL
    self.homeURL = homeURL
    self.environment = environment
  }

  var projectDirectoryURL: URL {
    rootURL.appendingPathComponent(".rt")
  }

  var projectLocalDirectoryURL: URL {
    projectDirectoryURL.appendingPathComponent("local")
  }

  var globalDirectoryURL: URL {
    if let xdgRoot = environment["XDG_CONFIG_HOME"], !xdgRoot.isEmpty {
      return URL(fileURLWithPath: xdgRoot, isDirectory: true)
        .appendingPathComponent("rt")
    }

    return homeURL
      .appendingPathComponent(".local")
      .appendingPathComponent("config")
      .appendingPathComponent("rt")
  }

  var globalLocalDirectoryURL: URL {
    globalDirectoryURL.appendingPathComponent("local")
  }

  var legacyProjectConfigURL: URL {
    rootURL.appendingPathComponent(".rt.json")
  }

  var legacyProjectLocalConfigURL: URL {
    rootURL.appendingPathComponent(".rt.local.json")
  }

  var gitIgnoreURL: URL {
    rootURL.appendingPathComponent(".gitignore")
  }

  func candidateURLs(scheme: String?, platform: String?) -> [URL] {
    let normalizedScheme = normalizedComponent(scheme)
    let normalizedPlatform = normalizedComponent(platform)

    return [
      scopedURL(root: projectLocalDirectoryURL, scheme: normalizedScheme, platform: normalizedPlatform),
      schemeURL(root: projectLocalDirectoryURL, scheme: normalizedScheme),
      platformURL(root: projectLocalDirectoryURL, platform: normalizedPlatform),
      baseURL(root: projectLocalDirectoryURL),
      scopedURL(root: projectDirectoryURL, scheme: normalizedScheme, platform: normalizedPlatform),
      schemeURL(root: projectDirectoryURL, scheme: normalizedScheme),
      platformURL(root: projectDirectoryURL, platform: normalizedPlatform),
      baseURL(root: projectDirectoryURL),
      scopedURL(root: globalLocalDirectoryURL, scheme: normalizedScheme, platform: normalizedPlatform),
      schemeURL(root: globalLocalDirectoryURL, scheme: normalizedScheme),
      platformURL(root: globalLocalDirectoryURL, platform: normalizedPlatform),
      baseURL(root: globalLocalDirectoryURL),
      scopedURL(root: globalDirectoryURL, scheme: normalizedScheme, platform: normalizedPlatform),
      schemeURL(root: globalDirectoryURL, scheme: normalizedScheme),
      platformURL(root: globalDirectoryURL, platform: normalizedPlatform),
      baseURL(root: globalDirectoryURL),
    ].compactMap { $0 }
  }

  private func normalizedComponent(_ component: String?) -> String? {
    guard let component else {
      return nil
    }

    let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  func baseURL(root: URL) -> URL {
    root.appendingPathComponent("config.json")
  }

  func platformURL(root: URL, platform: String?) -> URL? {
    guard let platform else {
      return nil
    }

    return root
      .appendingPathComponent("platforms")
      .appendingPathComponent(platform)
      .appendingPathExtension("json")
  }

  func schemeURL(root: URL, scheme: String?) -> URL? {
    guard let scheme else {
      return nil
    }

    return root
      .appendingPathComponent("schemes")
      .appendingPathComponent(scheme)
      .appendingPathExtension("json")
  }

  func scopedURL(root: URL, scheme: String?, platform: String?) -> URL? {
    guard let scheme, let platform else {
      return nil
    }

    return root
      .appendingPathComponent("schemes")
      .appendingPathComponent(scheme)
      .appendingPathComponent("platforms")
      .appendingPathComponent(platform)
      .appendingPathExtension("json")
  }
}
