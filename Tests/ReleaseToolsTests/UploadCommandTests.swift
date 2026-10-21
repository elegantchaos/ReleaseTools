// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Tests on 07/04/26.
//  All code (c) 2026 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Testing

@testable import ReleaseTools

/// Verifies upload receipt analysis and user-facing failure diagnostics.
struct UploadCommandTests {

  /// Unknown bundle failures retain the complete validation explanation.
  @Test func preservesOtherInvalidBundleErrors() {
    let error = UploadReceiptError(
      code: 90062,
      message: "This bundle is invalid. A different validation failed.",
      underlyingErrors: [],
      userInfo: nil
    )

    #expect(error.isInvalidBundleError)
    #expect(error.isAlreadyReleased == false)

    let description = UploadCommand.Error.rejected([error]).errorDescription ?? ""
    #expect(description.contains("[90062] This bundle is invalid."))
    #expect(description.contains("A different validation failed."))
    #expect(description.contains("This version has already been released.") == false)
  }

  /// A standalone train failure includes the affected version and submission restriction.
  @Test func preservesStandaloneInvalidPreReleaseTrainErrors() {
    let error = UploadReceiptError(
      code: 90186,
      message: "Invalid Pre-Release Train. The train version '3.0.1' is closed for new build submissions.",
      underlyingErrors: [],
      userInfo: nil
    )

    #expect(error.isInvalidPreReleaseTrainError)
    #expect(error.isAlreadyReleased == false)

    let description = UploadCommand.Error.rejected([error]).errorDescription ?? ""
    #expect(description.contains("[90186] Invalid Pre-Release Train."))
    #expect(description.contains("The train version '3.0.1' is closed for new build submissions."))
    #expect(description.contains("This version has already been released.") == false)
  }

  /// Xcode rejections read the exact version and build from the upload application's metadata.
  @Test(arguments: [
    ("/Applications/Xcodes/Xcode-27.2.0-Release.Candidate.app/Contents/SharedFrameworks/ContentDelivery.framework/Resources", "Xcode-27.2.0-Release.Candidate.app"),
    ("/Applications/Xcode.app/Contents/SharedFrameworks/ContentDelivery.framework/Resources", "Xcode.app"),
    ("/usr/local/lib/ContentDelivery.framework/Resources", ""),
  ])
  func explainsRejectedXcodeVersion(toolPath: String, applicationName: String) throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    var receiptToolPath = toolPath
    if !applicationName.isEmpty {
      let contents = root.appending(path: applicationName).appending(path: "Contents")
      try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
      let metadata = ["CFBundleShortVersionString": "27.2", "ProductBuildVersion": "27B48", "CFBundleVersion": "25400.60.4"]
      try PropertyListEncoder().encode(metadata).write(to: contents.appending(path: "version.plist"))
      receiptToolPath = contents.appending(path: "SharedFrameworks/ContentDelivery.framework/Resources").path
    }

    let stdout = #"""
      {
        "os-version": "Version 27.0.1",
        "product-errors": [{
          "code": 90301,
          "message": "This bundle is invalid. Apple is not currently accepting applications built with this version of Xcode.",
          "underlying-errors": [{
            "code": -19241,
            "message": "A server error occurred.",
            "underlying-errors": [],
            "user-info": {
              "description": "This bundle is invalid. Apple is not currently accepting applications built with this version of Xcode."
            }
          }],
          "user-info": { "NSLocalizedFailureReason": "n/a (ID: example-rejection-id)" }
        }],
        "tool-path": "\#(receiptToolPath)",
        "tool-version": "27.10.4 (2.2)"
      }
      """#

    do {
      _ = try UploadCommand.analyzeUploadOutput(stdout: stdout, stderr: "ERROR: [altool.main] ExitFailure (31)")
      Issue.record("Expected upload analysis to throw for a rejected Xcode version.")
    } catch let error as UploadCommand.Error {
      let description = try #require(error.errorDescription)
      let version = applicationName.isEmpty ? "" : " 27.2 (27B48)"
      #expect(description.trimmingCharacters(in: .whitespacesAndNewlines) == "Upload was rejected.\n\nXcode version\(version) not accepted by App Store Connect.")
      #expect(description.contains("25400.60.4") == false)
      #expect(description.contains("27.10.4") == false)
      #expect(description.contains("n/a") == false)
      #expect(description.contains("A server error occurred.") == false)
      #expect(description.contains("ExitFailure (31)") == false)
    }
  }

  /// Error 90301 is only specialized when Apple's message identifies an Xcode rejection.
  @Test func preservesOther90301Errors() {
    let error = UploadReceiptError(
      code: 90301,
      message: "This bundle is invalid. Another validation failed.",
      underlyingErrors: [],
      userInfo: nil
    )

    let description = UploadCommand.Error.rejected([error]).errorDescription ?? ""
    #expect(description.contains("[90301] This bundle is invalid. Another validation failed."))
    #expect(description.contains("Rebuild and export") == false)
  }

  /// Approved release versions produce a concise version-increment instruction.
  @Test func explainsWhenTheReleaseVersionHasAlreadyBeenReleased() throws {
    let stdout = #"""
      {
        "os-version" : "Version 26.4 (Build 25E246)",
        "product-errors" : [
          {
            "code" : 90062,
            "message" : "This bundle is invalid. The value for key CFBundleShortVersionString [3.0.1] in the Info.plist file must contain a higher version than that of the previously approved version [3.0.1].",
            "underlying-errors" : [],
            "user-info" : {
              "NSLocalizedFailureReason" : "The server’s response was: ‘{ code = 90062; description = \"This bundle is invalid.\"; }’."
            }
          },
          {
            "code" : 90186,
            "message" : "Invalid Pre-Release Train. The train version '3.0.1' is closed for new build submissions.",
            "underlying-errors" : [],
            "user-info" : {
              "NSLocalizedFailureReason" : "The server’s response was: ‘{ code = 90186; description = \"Invalid Pre-Release Train.\"; }’."
            }
          }
        ],
        "tool-path" : "/Applications/Xcode.app/Contents/SharedFrameworks/ContentDelivery.framework/Resources",
        "tool-version" : "26.30.4 (173004)"
      }
      """#

    do {
      _ = try UploadCommand.analyzeUploadOutput(stdout: stdout, stderr: "")
      Issue.record("Expected upload analysis to throw for a closed release train.")
    } catch {
      let description = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
      #expect(description.contains("This version has already been released."))
      #expect(description.contains("Increase CFBundleShortVersionString before submitting a new build."))
      #expect(description.contains("The server’s response was:") == false)
      #expect(description.contains("[90062]") == false)
      #expect(description.contains("[90186]") == false)
    }
  }

  /// Sandbox errors extract entitlement guidance and executable paths from the receipt.
  @Test func summarizesSandboxReceiptRejection() throws {
    let stdout = #"""
      {
        "os-version" : "Version 26.4 (Build 25E246)",
        "product-errors" : [
          {
            "code" : 90296,
            "message" : "App sandbox not enabled. The following executables must include the \"com.apple.security.app-sandbox\" entitlement with a Boolean value of true in the entitlements property list: [( \"com.elegantchaos.clocksync.pkg/Payload/ClockSync.app/Contents/MacOS/ClockSync\" )] Refer to App Sandbox page at https://developer.apple.com/documentation/security/app_sandbox for more information on sandboxing your app.",
            "underlying-errors" : [
              {
                "code" : -19241,
                "message" : "A server error occurred.",
                "underlying-errors" : [

                ],
                "user-info" : {
                  "NSLocalizedDescription" : "A server error occurred.",
                  "code" : "90296",
                  "description" : "App sandbox not enabled. The following executables must include the \"com.apple.security.app-sandbox\" entitlement with a Boolean value of true in the entitlements property list: [( \"com.elegantchaos.clocksync.pkg/Payload/ClockSync.app/Contents/MacOS/ClockSync\" )] Refer to App Sandbox page at https://developer.apple.com/documentation/security/app_sandbox for more information on sandboxing your app."
                }
              }
            ],
            "user-info" : {
              "NSLocalizedDescription" : "App sandbox not enabled. The following executables must include the \"com.apple.security.app-sandbox\" entitlement with a Boolean value of true in the entitlements property list: [( \"com.elegantchaos.clocksync.pkg/Payload/ClockSync.app/Contents/MacOS/ClockSync\" )] Refer to App Sandbox page at https://developer.apple.com/documentation/security/app_sandbox for more information on sandboxing your app.",
              "NSLocalizedFailureReason" : "The server’s response was: ‘{\n    code = 90296;\n    description = \"App sandbox not enabled. The following executables must include the \\\"com.apple.security.app-sandbox\\\" entitlement with a Boolean value of true in the entitlements property list: [( \\\"com.elegantchaos.clocksync.pkg/Payload/ClockSync.app/Contents/MacOS/ClockSync\\\" )] Refer to App Sandbox page at https://developer.apple.com/documentation/security/app_sandbox for more information on sandboxing your app.\";\n}’.",
              "NSUnderlyingError" : "Error Domain=IrisAPI Code=-19241 \"A server error occurred.\" UserInfo={code=90296, NSLocalizedDescription=A server error occurred., description=App sandbox not enabled. The following executables must include the \"com.apple.security.app-sandbox\" entitlement with a Boolean value of true in the entitlements property list: [( \"com.elegantchaos.clocksync.pkg/Payload/ClockSync.app/Contents/MacOS/ClockSync\" )] Refer to App Sandbox page at https://developer.apple.com/documentation/security/app_sandbox for more information on sandboxing your app.}",
              "iris-code" : "90296"
            }
          }
        ],
        "tool-path" : "/Applications/Xcode.app/Contents/SharedFrameworks/ContentDelivery.framework/Resources",
        "tool-version" : "26.30.4 (173004)"
      }
      """#
    let stderr = """
      Running altool at path '/Applications/Xcode.app/Contents/SharedFrameworks/ContentDelivery.framework/Resources/altool'...

      2026-04-07 11:22:31.572 ERROR: [ContentDelivery.Uploader.BF8C44D80]
      =======================================
      UPLOAD FAILED with 1 error
      =======================================
      2026-04-07 11:22:31.580 ERROR: [altool.10556ECA0] ExitFailure (31)
      """

    do {
      _ = try UploadCommand.analyzeUploadOutput(stdout: stdout, stderr: stderr)
      Issue.record("Expected upload analysis to throw for a rejected receipt.")
    } catch {
      let description = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
      #expect(description.contains("Upload was rejected."))
      #expect(description.contains("[90296] App sandbox not enabled."))
      #expect(description.contains("Enable the \"com.apple.security.app-sandbox\" entitlement."))
      #expect(description.contains("Executable: com.elegantchaos.clocksync.pkg/Payload/ClockSync.app/Contents/MacOS/ClockSync"))
      #expect(description.contains("The server’s response was:") == false)
      #expect(description.contains("ExitFailure (31)") == false)
    }
  }

  /// Missing receipt output still reports a missing upload file from stderr.
  @Test func fallsBackToStderrWhenNoReceiptWasReturned() throws {
    let stderr = "2026-04-07 11:22:31.580 ERROR: File does not exist at path /tmp/Missing.pkg"

    do {
      _ = try UploadCommand.analyzeUploadOutput(stdout: "", stderr: stderr)
      Issue.record("Expected upload analysis to throw for a missing upload file.")
    } catch {
      let description = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
      #expect(description.contains("Upload file not found."))
      #expect(description.contains("/tmp/Missing.pkg"))
    }
  }

  /// Unstructured failures report the final stderr error instead of an empty uploader heading.
  @Test func prefersTheLastUsefulStderrErrorLine() throws {
    let stderr = """
      Running altool at path '/Applications/Xcode.app/Contents/SharedFrameworks/ContentDelivery.framework/Resources/altool'...
      2026-04-07 11:22:31.572 ERROR: [ContentDelivery.Uploader.BF8C44D80]
      =======================================
      UPLOAD FAILED with 1 error
      =======================================
      2026-04-07 11:22:31.580 ERROR: [altool.10556ECA0] ExitFailure (31)
      """

    do {
      _ = try UploadCommand.analyzeUploadOutput(stdout: "", stderr: stderr)
      Issue.record("Expected upload analysis to surface the final stderr error line.")
    } catch {
      let description = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
      #expect(description.contains("Upload failed with an unknown error."))
      #expect(description.contains("ExitFailure (31)"))
      #expect(description.contains("[ContentDelivery.Uploader.BF8C44D80]") == false)
    }
  }
}
