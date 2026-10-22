// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 12/08/2025.
//  Copyright © 2025 Elegant Chaos Limited. All rights reserved.
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
