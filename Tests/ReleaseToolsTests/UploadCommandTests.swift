// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Tests on 07/04/26.
//  All code (c) 2026 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Testing

@testable import ReleaseTools

struct UploadCommandTests {

  @Test func doesNotClassifyOtherInvalidBundlesAsReleasedVersions() {
    let error = UploadReceiptError(
      code: 90062,
      message: "This bundle is invalid. A different validation failed.",
      underlyingErrors: [],
      userInfo: nil
    )

    #expect(error.indicatesReleasedVersion == false)
  }

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
      #expect(!description.contains("The server’s response was:"))
      #expect(!description.contains("ExitFailure (31)"))
    }
  }

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
      #expect(!description.contains("[ContentDelivery.Uploader.BF8C44D80]"))
    }
  }
}
