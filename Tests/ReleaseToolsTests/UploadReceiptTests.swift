// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 21/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Testing

@testable import ReleaseTools

/// Verifies that unavailable or incomplete Xcode metadata does not hide an upload rejection.
struct UploadReceiptTests {
  /// Missing, malformed, or incomplete metadata falls back to a compact unversioned rejection.
  @Test(arguments: ["missing", "malformed", "missing-version", "missing-build", "empty-version", "empty-build", "wrong-type"])
  func toleratesUnavailableXcodeMetadata(scenario: String) throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let contents = root.appending(path: "Xcode-99.0.app/Contents")
    try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
    let versionURL = contents.appending(path: "version.plist")
    var metadata = ["CFBundleShortVersionString": "27.2", "ProductBuildVersion": "27B48"]
    switch scenario {
      case "missing-version": metadata.removeValue(forKey: "CFBundleShortVersionString")
      case "missing-build": metadata.removeValue(forKey: "ProductBuildVersion")
      case "empty-version": metadata["CFBundleShortVersionString"] = " "
      case "empty-build": metadata["ProductBuildVersion"] = " "
      default: break
    }
    if scenario == "malformed" {
      try Data("invalid plist".utf8).write(to: versionURL)
    } else if scenario == "wrong-type" {
      try PropertyListEncoder().encode(["CFBundleShortVersionString": 27, "ProductBuildVersion": 48]).write(to: versionURL)
    } else if scenario != "missing" {
      try PropertyListEncoder().encode(metadata).write(to: versionURL)
    }

    let receipt: [String: Any] = [
      "os-version": "27.0",
      "tool-path": contents.appending(path: "SharedFrameworks/ContentDelivery.framework/Resources").path,
      "tool-version": "27.10.4 (2.2)",
      "product-errors": [
        [
          "code": 90301,
          "message": "This bundle is invalid. Apple is not currently accepting applications built with this version of Xcode.",
          "underlying-errors": [],
        ]
      ],
    ]
    let stdout = String(decoding: try JSONSerialization.data(withJSONObject: receipt), as: UTF8.self)
    do {
      _ = try UploadCommand.analyzeUploadOutput(stdout: stdout, stderr: "")
      Issue.record("Expected a rejected upload even when Xcode metadata is unavailable.")
    } catch let error as UploadCommand.Error {
      let description = try #require(error.errorDescription)
      #expect(description.trimmingCharacters(in: .whitespacesAndNewlines) == "Upload was rejected.\n\nXcode version not accepted by App Store Connect.")
    }
  }
}
