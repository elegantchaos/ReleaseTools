// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 18/07/2025.
//  Copyright © 2025 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

extension JSONDecoder.KeyDecodingStrategy {
  /// Maps dash-separated receipt field names into camel-case coding keys.
  static var dashCase: JSONDecoder.KeyDecodingStrategy {
    .custom { codingPath in
      guard let last = codingPath.last else {
        preconditionFailure("A decoded object key must have a coding path.")
      }
      let key = last.stringValue
      let dashed =
        key
        .split(separator: "-")
        .enumerated()
        .map { $0.offset > 0 ? $0.element.capitalized : $0.element.lowercased() }
        .joined()
      return AnyKey(stringValue: dashed)
    }
  }
}
