// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 21/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// One receipt error reported by Apple's upload tooling.
struct UploadReceiptError: Codable, Sendable {
  /// Apple's numeric validation error code.
  let code: Int

  /// The complete primary validation message supplied by Apple.
  let message: String

  /// Lower-level failures supplied with the primary error.
  let underlyingErrors: [UploadReceiptError]

  /// Supplementary diagnostic fields supplied by the upload tool.
  let userInfo: [String: String]?
}

extension UploadReceiptError {
  /// The error code indicates an invalid bundle.
  var isInvalidBundleError: Bool {
    code == 90062
  }

  /// The error code indicates an invalid pre-release train.
  var isInvalidPreReleaseTrainError: Bool {
    code == 90186
  }

  /// The server message indicates that the app's release version has already been approved.
  var isAlreadyReleased: Bool {
    message.contains("The value for key CFBundleShortVersionString")
      && message.contains("must contain a higher version than that of the previously approved version")
  }

  /// Apple's validation message explicitly rejects the Xcode version used to build the app.
  var isUnsupportedXcode: Bool {
    code == 90301 && message.contains("Apple is not currently accepting applications built with this version of Xcode")
  }

  /// A compact multi-line summary suitable for CLI error output.
  func compactSummary(xcodeVersion: String?) -> String {
    if isUnsupportedXcode {
      let version = xcodeVersion.map { " \($0)" } ?? ""
      return "Xcode version\(version) not accepted by App Store Connect."
    }

    let summary = compactMessage
    var lines = ["[\(code)] \(summary)"]

    if summary == "App sandbox not enabled." {
      lines.append("- Enable the \"com.apple.security.app-sandbox\" entitlement.")
      for executable in sandboxExecutables {
        lines.append("- Executable: \(executable)")
      }
    } else if let reason = userInfo?["NSLocalizedFailureReason"]?.trimmingCharacters(in: .whitespacesAndNewlines),
      !reason.isEmpty
    {
      lines.append("- \(reason)")
    }

    return lines.joined(separator: "\n")
  }

  /// The complete primary message, with a focused heading for recognized sandbox failures.
  var compactMessage: String {
    if message.hasPrefix("App sandbox not enabled.") {
      return "App sandbox not enabled."
    }

    return message.trimmingCharacters(in: .whitespacesAndNewlines)
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
    return slice.matches(of: /"([^"]+)"/).map { String($0.output.1) }
  }
}
