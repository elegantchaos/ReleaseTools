// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/04/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Top-level upload receipt returned by Apple's upload tooling.
struct UploadReceipt: Codable {
  /// The operating system version reported by the upload tool.
  let osVersion: String

  /// The location of the upload tool used for this submission.
  let toolPath: String

  /// The upload tool's version string.
  let toolVersion: String

  /// Validation failures returned for a rejected submission.
  let productErrors: [UploadReceiptError]?

  /// Apple's confirmation message for an accepted submission.
  let successMessage: String?

  /// Delivery information for a successful upload.
  let details: UploadReceiptDetails?

  /// Reads the upload application's marketing version and product build from its version plist.
  var xcodeVersion: String? {
    var applicationURL = URL(filePath: toolPath)
    while applicationURL.pathExtension != "app" {
      let parent = applicationURL.deletingLastPathComponent()
      guard parent != applicationURL else { return nil }
      applicationURL = parent
    }

    let versionURL = applicationURL.appending(path: "Contents/version.plist")
    guard
      let data = try? Data(contentsOf: versionURL),
      let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
      let metadata = plist as? [String: Any],
      let version = metadata["CFBundleShortVersionString"] as? String,
      let build = metadata["ProductBuildVersion"] as? String
    else { return nil }

    let trimmedVersion = version.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedBuild = build.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedVersion.isEmpty, !trimmedBuild.isEmpty else { return nil }
    return "\(trimmedVersion) (\(trimmedBuild))"
  }
}
