// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 20/03/26.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

enum RTConfigError: Error, CustomStringConvertible {
  case invalidConfigurationFile(URL, Error)
  case invalidLegacyConfigurationFile(URL, Error)
  case mixedLegacyAndCanonicalSchema(URL)
  case failedToMigrate(URL, Error)
  case failedToUpdateGitIgnore(URL, Error)

  var description: String {
    switch self {
      case .invalidConfigurationFile(let url, let error):
        return "Failed to load configuration file at \(url.path).\n\n\(error)"

      case .invalidLegacyConfigurationFile(let url, let error):
        return "Failed to load legacy configuration file at \(url.path).\n\n\(error)"

      case .mixedLegacyAndCanonicalSchema(let url):
        return """
          The configuration file at \(url.path) uses the new canonical schema in a legacy file location or mixes the old selector-key schema with the new canonical schema.

          Move it into the `.rt/` layout or convert it back to the legacy selector-key schema before retrying migration.
          """

      case .failedToMigrate(let url, let error):
        return "Failed to migrate configuration file at \(url.path).\n\n\(error)"

      case .failedToUpdateGitIgnore(let url, let error):
        return "Failed to update \(url.path) to ignore local ReleaseTools config.\n\n\(error)"
    }
  }
}
