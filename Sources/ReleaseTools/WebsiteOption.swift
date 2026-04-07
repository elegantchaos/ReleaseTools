// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/04/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation

/// Common command-line option for locating the website repository used for publishing.
struct WebsiteOption: ParsableArguments {
  @Option(help: "The local path to the repository containing the website, where the appcast and zip archives live. Defaults to `Dependencies/Website`.")
  var website: String?

  /// The resolved website location.
  var websiteURL: URL {
    if let path = website {
      return URL(fileURLWithPath: path)
    } else {
      return URL(fileURLWithPath: "Dependencies/Website/")
    }
  }
}
