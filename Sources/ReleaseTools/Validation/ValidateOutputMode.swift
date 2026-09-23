// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 23/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// Output verbosity modes supported by `rt validate`.
enum ValidateOutputMode: String {
  /// Print selected diagnostics from validation output.
  case filtered
  /// Suppress streamed validation output.
  case quiet
  /// Print raw validation output.
  case raw
}
