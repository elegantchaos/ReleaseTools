// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 23/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

/// Summary record for one validation step in the final report.
struct ValidationStepRecord {
  /// Human-readable step summary.
  let summary: String
  /// Final step status.
  let status: ValidationStepStatus
  /// Whether the step output included warnings.
  let warningsPresent: Bool
  /// Optional path to the step's log file.
  let logPath: String?
}
