// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 18/07/25.
//  All code (c) 2025 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// An implementation of CodingKey that's useful for combining and transforming keys as strings.
struct AnyKey: CodingKey {
  var stringValue: String
  var intValue: Int?

  init?(stringValue: String) {
    self.stringValue = stringValue
    self.intValue = nil
  }

  init?(intValue: Int) {
    self.stringValue = String(intValue)
    self.intValue = intValue
  }
}

extension JSONDecoder.KeyDecodingStrategy {
  static var dashCase: JSONDecoder.KeyDecodingStrategy {
    .custom { codingPath in
      let key = codingPath.last!.stringValue
      let dashed =
        key
        .split(separator: "-")
        .enumerated()  // get indices
        .map { $0.offset > 0 ? $0.element.capitalized : $0.element.lowercased() }
        .joined()
      return AnyKey(stringValue: dashed)!
    }
  }
}
