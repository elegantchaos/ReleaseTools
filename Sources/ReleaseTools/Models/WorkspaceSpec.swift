// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 23/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Minimal workspace metadata decoded from `xcodebuild -list -json`.
struct WorkspaceSpec: Decodable {
  /// The workspace name reported by Xcode.
  let name: String
  /// Schemes shared by the workspace.
  let schemes: [String]
}
