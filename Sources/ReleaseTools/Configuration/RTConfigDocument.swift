// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 20/03/26.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

struct RTConfigDocument: Codable, Equatable {
  struct Defaults: Codable, Equatable {
    var scheme: String?

    var isEmpty: Bool {
      scheme == nil
    }
  }

  var defaults: Defaults?
  var settings: BasicSettings?

  var isEmpty: Bool {
    (defaults?.isEmpty ?? true) && (settings?.isEmpty ?? true)
  }
}
