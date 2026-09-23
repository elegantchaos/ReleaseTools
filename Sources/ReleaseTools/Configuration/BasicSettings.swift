// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 20/03/26.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

struct BasicSettings: Codable, Equatable {
  var keychain: String?
  var apiKey: String?
  var apiIssuer: String?

  var isEmpty: Bool {
    keychain == nil && apiKey == nil && apiIssuer == nil
  }
}
