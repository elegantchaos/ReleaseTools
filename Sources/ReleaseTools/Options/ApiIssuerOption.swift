// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/04/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser

/// Common command-line option for selecting an App Store Connect issuer.
struct ApiIssuerOption: ParsableArguments {
  /// App Store Connect API issuer identifier supplied by the caller.
  @Option(name: .customLong("api-issuer"), help: "The App Store Connect issuer ID we're using.")
  var issuer: String?
}
