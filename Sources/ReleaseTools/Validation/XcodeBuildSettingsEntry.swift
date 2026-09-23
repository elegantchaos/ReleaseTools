// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 23/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// Minimal build settings metadata decoded from `xcodebuild -showBuildSettings -json`.
struct XcodeBuildSettingsEntry: Decodable {
  /// Build settings indexed by their Xcode keys.
  let buildSettings: [String: String]
}
