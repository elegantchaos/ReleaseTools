// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 20/03/26.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Configuration
import Foundation

struct RTConfigReader {
  let config: ConfigReader

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

  var defaultScheme: String? {
    config.string(forKey: "defaults.scheme")
  }

  var settings: BasicSettings {
    BasicSettings(
      keychain: config.string(forKey: "settings.keychain"),
      apiKey: config.string(forKey: "settings.apiKey", isSecret: true),
      apiIssuer: config.string(forKey: "settings.apiIssuer", isSecret: true)
    )
  }
}
