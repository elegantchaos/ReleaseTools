// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/04/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation

/// Common command-line option for locating the updates folder within the website repository.
struct UpdatesOption: ParsableArguments {
  @Option(help: "The local path to the updates folder inside the website repository. Defaults to `Dependencies/Website/updates`.")
  var updates: String?

  /// The resolved updates location.
  var url: URL {
    if let path = updates {
      return URL(fileURLWithPath: path)
    } else {
      return URL(fileURLWithPath: "Dependencies/Website/updates")
    }
  }

  /// The resolved updates path as a string.
  var path: String {
    url.path
  }
}
