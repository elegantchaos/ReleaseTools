// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 11/03/20.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation

struct SchemeOption: ParsableArguments {
  @Option(help: "The scheme we're building.")
  var scheme: String?
}

struct UserOption: ParsableArguments {
  @Option(help: "The App Store Connect user we're notarizing as.")
  var user: String?
}

struct ApiKeyOption: ParsableArguments {
  @Option(name: .customLong("api-key"), help: "The App Store Connect api key ID we're using.")
  var key: String?
}

struct ApiIssuerOption: ParsableArguments {
  @Option(name: .customLong("api-issuer"), help: "The App Store Connect issuer ID we're using.")
  var issuer: String?
}

struct PlatformOption: ParsableArguments {
  @Option(help: "The platform to build for. Should be one of: macOS, iOS, tvOS, watchOS.")
  var platform: String?
}

struct WebsiteOption: ParsableArguments {
  @Option(help: "The local path to the repository containing the website, where the appcast and zip archives live. Defaults to `Dependencies/Website`.")
  var website: String?

  var websiteURL: URL {
    if let path = website {
      return URL(fileURLWithPath: path)
    } else {
      return URL(fileURLWithPath: "Dependencies/Website/")
    }
  }
}

struct UpdatesOption: ParsableArguments {
  @Option(help: "The local path to the updates folder inside the website repository. Defaults to `Dependencies/Website/updates`.")
  var updates: String?

  var url: URL {
    if let path = updates {
      return URL(fileURLWithPath: path)
    } else {
      return URL(fileURLWithPath: "Dependencies/Website/updates")
    }
  }

  var path: String {
    return url.path
  }
}

struct CommonOptions: ParsableArguments {
  @Flag(help: "Show the external commands that we're executing, and the output from them.") var showOutput = false
  @Flag(help: "Show extra logging.") var verbose = false
  @Option(help: "The workspace we're operating on.")
  var workspace: String?
}

struct BuildOptions: ParsableArguments {
  @Option(name: .customLong("offset"), help: "Integer offset to apply to the build number.") var offset: UInt?
  @Flag(help: "Calculate builds by counting commits. If false, we instead look for the highest existing build tag, and increment it.") var countCommits: Bool = true
}
