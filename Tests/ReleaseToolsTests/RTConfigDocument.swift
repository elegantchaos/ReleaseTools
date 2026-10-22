// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 20/03/2026.
//  Copyright © 2020 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

@testable import ReleaseTools

/// Encodes canonical configuration fixtures for reader and engine tests.
struct RTConfigDocument: Encodable {
  /// Optional default command selections.
  var defaults: Defaults?

  /// Optional authentication and keychain settings.
  var settings: BasicSettings?
}

extension RTConfigDocument {
  /// Default command selections in a fixture document.
  struct Defaults: Encodable {
    /// Scheme selected when no command-line override is supplied.
    var scheme: String?
  }
}
