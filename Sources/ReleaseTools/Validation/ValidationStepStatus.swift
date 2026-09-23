// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 23/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// Result status for each recorded validation step.
enum ValidationStepStatus: String {
  /// The step succeeded.
  case pass = "PASS"
  /// The step failed.
  case fail = "FAIL"
  /// The step was skipped.
  case skip = "SKIP"
}
