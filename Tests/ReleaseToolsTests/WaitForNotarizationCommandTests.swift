// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 23/09/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Testing

@testable import ReleaseTools

/// Tests the user-facing diagnostics produced by the `wait` command.
struct WaitForNotarizationCommandTests {
  /// Wrapped errors show their localized description rather than their debug form.
  @Test func wrappedErrorsUseLocalizedDescriptions() {
    let underlying = XcodeArchive.Error.missingRequiredMetadata(
      URL(fileURLWithPath: "/tmp/Example.xcarchive/Info.plist"),
      ["ApplicationProperties.Team"]
    )
    let expected = underlying.errorDescription ?? ""

    let errors: [WaitForNotarizationCommand.Error] = [
      .fetchingStatusFailed(underlying),
      .exportingNotarizedAppFailed(underlying),
    ]

    for error in errors {
      let description = error.errorDescription ?? ""
      #expect(description.contains(expected))
      #expect(!description.contains("missingRequiredMetadata"))
    }
  }

  /// A successful status response is reported as success.
  @Test func successResponseIsSuccess() {
    let status = WaitForNotarizationCommand.status(fromResponse: response(["Status": "success"]))
    #expect(status == .success)
  }

  /// An in-progress status response is reported as pending, so polling continues.
  @Test func inProgressResponseIsPending() {
    let status = WaitForNotarizationCommand.status(fromResponse: response(["Status": "in progress"]))
    #expect(status == .pending("in progress"))
  }

  /// An unreadable status response is reported as unknown, so polling continues.
  @Test func unreadableResponseIsUnknown() {
    let status = WaitForNotarizationCommand.status(fromResponse: Data("not a plist".utf8))
    #expect(status == nil)
  }

  /// An invalid status response is reported as a rejection that includes the log's issues.
  @Test func invalidResponseIsRejectedWithReport() throws {
    let logURL = try #require(URL(string: "https://example.com/log.json"))
    let log: [String: Any] = [
      "statusSummary": "Archive contains critical validation errors",
      "issues": [
        [
          "message": "The binary is not signed.",
          "path": "Example.zip/Example.app/Contents/MacOS/Example",
          "severity": "error",
        ]
      ],
    ]
    let logData = try JSONSerialization.data(withJSONObject: log)

    let status = WaitForNotarizationCommand.status(
      fromResponse: response([
        "Status": "invalid",
        "Status Message": "Package Invalid",
        "LogFileURL": logURL.absoluteString,
      ]),
      loadLog: { $0 == logURL ? logData : nil }
    )

    guard case .invalid(let report) = status else {
      Issue.record("Expected an invalid status, got \(String(describing: status)).")
      return
    }
    #expect(report.contains("Package Invalid."))
    #expect(report.contains("Archive contains critical validation errors."))
    #expect(report.contains("#1 Example (error):\nThe binary is not signed."))
  }

  /// A rejection's description includes the notarization report.
  @Test func notarizationFailedDescriptionIncludesReport() {
    let description =
      WaitForNotarizationCommand.Error.notarizationFailed("Package Invalid.\n")
      .errorDescription ?? ""
    #expect(description.contains("Notarization failed."))
    #expect(description.contains("Package Invalid."))
  }

  /// Encodes a notarization-info response in the XML plist format returned by `altool`.
  private func response(_ info: [String: String]) -> Data {
    let plist: [String: Any] = ["notarization-info": info]
    return (try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0))
      ?? Data()
  }
}
