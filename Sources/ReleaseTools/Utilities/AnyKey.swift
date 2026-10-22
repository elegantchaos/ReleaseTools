// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 21/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// An implementation of CodingKey that's useful for combining and transforming keys as strings.
struct AnyKey: CodingKey {
  /// Text representation supplied to the decoder.
  var stringValue: String

  /// Integer representation when the key was constructed from an index.
  var intValue: Int?

  /// Constructs a coding key with its corresponding text and optional integer value.
  init(stringValue: String) {
    self.stringValue = stringValue
    self.intValue = nil
  }

  /// Constructs a coding key with its corresponding text and optional integer value.
  init(intValue: Int) {
    self.stringValue = String(intValue)
    self.intValue = intValue
  }
}
