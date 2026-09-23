// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 23/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// Derived filesystem and environment paths for a validation run.
struct ToolingPaths {
  /// Root directory for validation logs.
  let verifyRoot: String
  /// Derived data directory for Xcode validation.
  let derivedDataPath: String
  /// Environment variables applied to validation subprocesses.
  let env: [String: String]
}
