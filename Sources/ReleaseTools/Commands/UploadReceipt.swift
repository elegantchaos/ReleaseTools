// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/04/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// One receipt error reported by Apple's upload tooling.
struct UploadReceiptError: Codable, Sendable {
  let code: Int
  let message: String
  let underlyingErrors: [UploadReceiptError]
  let userInfo: [String: String]?
}

/// Additional success details returned by Apple's upload tooling.
struct UploadReceiptDetails: Codable, Sendable {
  let deliveryUuid: String
  let transferred: String
}

/// Top-level upload receipt returned by Apple's upload tooling.
struct UploadReceipt: Codable {
  let osVersion: String
  let toolPath: String
  let toolVersion: String
  let productErrors: [UploadReceiptError]?
  let successMessage: String?
  let details: UploadReceiptDetails?
}

extension UploadReceiptError {
  /// A compact multi-line summary suitable for CLI error output.
  var compactSummary: String {
    let summary = compactMessage
    var lines = ["[\(code)] \(summary)"]

    if summary == "App sandbox not enabled." {
      lines.append("- Enable the \"com.apple.security.app-sandbox\" entitlement.")
      for executable in sandboxExecutables {
        lines.append("- Executable: \(executable)")
      }
    } else if
      let reason = userInfo?["NSLocalizedFailureReason"]?.trimmingCharacters(in: .whitespacesAndNewlines),
      !reason.isEmpty
    {
      lines.append("- \(reason)")
    }

    return lines.joined(separator: "\n")
  }

  /// A normalized single-line summary of the primary receipt failure.
  var compactMessage: String {
    if message.hasPrefix("App sandbox not enabled.") {
      return "App sandbox not enabled."
    }

    let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
    if let sentenceEnd = trimmed.firstIndex(of: ".") {
      return String(trimmed[...sentenceEnd])
    }

    return trimmed
  }

  /// Executable paths extracted from sandboxing failures.
  var sandboxExecutables: [String] {
    guard let start = message.range(of: "entitlements property list: [")?.upperBound else {
      return []
    }

    guard let end = message[start...].range(of: "] Refer")?.lowerBound else {
      return []
    }

    let slice = String(message[start..<end])
    let pattern = try? NSRegularExpression(pattern: #""([^"]+)""#)
    let range = NSRange(slice.startIndex..<slice.endIndex, in: slice)
    let matches = pattern?.matches(in: slice, range: range) ?? []

    return matches.compactMap { match in
      guard let capture = Range(match.range(at: 1), in: slice) else {
        return nil
      }

      return String(slice[capture])
    }
  }
}
