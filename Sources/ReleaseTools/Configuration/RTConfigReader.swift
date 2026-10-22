// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 20/03/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Configuration
import Foundation

/// Loads layered configuration snapshots from the paths resolved by `RTConfigPaths`.
struct RTConfigReader {
  /// Layered provider snapshot used to resolve effective configuration values.
  private let config: ConfigReader

  /// Creates a reader using the candidate config files for the active scheme and platform.
  init(paths: RTConfigPaths, scheme: String?, platform: String?) async throws {
    var providers: [any ConfigProvider] = []
    for url in paths.candidateURLs(scheme: scheme, platform: platform) {
      do {
        let fileConfig = ConfigReader(
          provider: InMemoryProvider(values: [
            AbsoluteConfigKey(["filePath"]): ConfigValue(.string(url.path), isSecret: false),
            AbsoluteConfigKey(["allowMissing"]): ConfigValue(.bool(true), isSecret: false),
          ]))
        let provider = try await FileProvider<JSONSnapshot>(
          config: fileConfig
        )
        providers.append(provider)
      } catch {
        throw Error.invalidConfigurationFile(url, error)
      }
    }

    self.config = ConfigReader(providers: providers)
  }

  /// The default scheme from layered configuration.
  var defaultScheme: String? {
    config.string(forKey: "defaults.scheme")
  }

  /// Effective release settings from layered configuration.
  var settings: BasicSettings {
    BasicSettings(
      keychain: config.string(forKey: "settings.keychain"),
      apiKey: config.string(forKey: "settings.apiKey", isSecret: true),
      apiIssuer: config.string(forKey: "settings.apiIssuer", isSecret: true)
    )
  }
}

extension RTConfigReader {
  /// Failures loading canonical JSON configuration.
  enum Error: Swift.Error, LocalizedError {
    /// A configuration document could not be read or decoded.
    case invalidConfigurationFile(URL, any Swift.Error)

    /// Includes the failed document's path and the provider's underlying error.
    var errorDescription: String? {
      switch self {
        case .invalidConfigurationFile(let url, let error):
          return "Failed to load configuration file at \(url.path).\n\n\(error)"
      }
    }
  }
}
