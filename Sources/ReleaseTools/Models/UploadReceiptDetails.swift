// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 21/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Additional success details returned by Apple's upload tooling.
struct UploadReceiptDetails: Codable, Sendable {
  /// Apple's identifier for the uploaded delivery.
  let deliveryUuid: String

  /// The amount of data transferred, as reported by the upload tool.
  let transferred: String
}
