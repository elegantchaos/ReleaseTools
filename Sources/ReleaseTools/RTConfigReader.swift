// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 20/03/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Configuration
import Foundation

/// Loads layered configuration snapshots from the paths resolved by `RTConfigPaths`.
struct RTConfigReader {
  let config: ConfigReader

  /// Creates a reader using the candidate config files for the active scheme and platform.
  init(paths: RTConfigPaths, scheme: String?, platform: String?) async throws {
    var providers: [any ConfigProvider] = []
    for url in paths.candidateURLs(scheme: scheme, platform: platform) {
      do {
        let fileConfig = ConfigReader(provider: InMemoryProvider(values: [
          AbsoluteConfigKey(["filePath"]): ConfigValue(.string(url.path), isSecret: false),
          AbsoluteConfigKey(["allowMissing"]): ConfigValue(.bool(true), isSecret: false),
        ]))
        let provider = try await FileProvider<JSONSnapshot>(
          config: fileConfig
        )
        providers.append(provider)
      } catch {
        throw RTConfigError.invalidConfigurationFile(url, error)
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
