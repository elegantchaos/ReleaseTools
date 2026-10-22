// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 20/03/2026.
//  Copyright © 2020 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Authentication and keychain overrides resolved independently across configuration scopes.
struct BasicSettings: Codable, Equatable {
  /// Keychain containing release signing credentials.
  var keychain: String?

  /// App Store Connect API key selection.
  var apiKey: String?

  /// App Store Connect API issuer selection.
  var apiIssuer: String?
}
