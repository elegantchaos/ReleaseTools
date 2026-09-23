// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 23/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// Captured output and exit information for one validation subprocess.
struct ValidationCommandResult {
  /// Process termination status.
  let status: Int32
  /// Combined subprocess output.
  let output: String
  /// Whether the output included warnings.
  let warningsPresent: Bool
}
