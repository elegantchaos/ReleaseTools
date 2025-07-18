// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 25/02/20.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation
import Runner

enum UploadError: Error {
  case decodingUploadReceiptFailed(Error)
  case savingUploadReceiptFailed(Error)
  case uploadingFailedWithErrors([UploadReceiptError])
}

extension UploadError: LocalizedError {
  public var errorDescription: String? {
    switch self {
      case .savingUploadReceiptFailed(let error):
        return "Saving upload receipt failed.\n\(error)"

      case .decodingUploadReceiptFailed(let error):
        return "Decoding upload receipt failed.\n\(error)"

      case .uploadingFailedWithErrors(let errors):
        var log = "Uploading failed with errors:\n"
        for error in errors {
          log += "\n\(error.message) (\(error.code))\n"
          if let userInfo = error.userInfo {
            if let reason = userInfo["NSLocalizedFailureReason"] {
              log += "- \(reason)\n"
            }
          }
        }

        return log
    }
  }
}

enum UploadRunnerError: Runner.Error {
  case uploadingFailed

  func description(for session: Runner.Session) async -> String {
    async let stderr = session.stderr.string
    switch self {
      case .uploadingFailed: return "Uploading failed.\n\(await stderr)"
    }
  }
}

struct UploadCommand: AsyncParsableCommand {
  static var configuration: CommandConfiguration {
    CommandConfiguration(
      commandName: "upload",
      abstract: "Upload the archived app to Apple Connect portal for processing."
    )
  }

  @OptionGroup() var scheme: SchemeOption
  @OptionGroup() var user: UserOption
  @OptionGroup() var apiKey: ApiKeyOption
  @OptionGroup() var apiIssuer: ApiIssuerOption
  @OptionGroup() var platform: PlatformOption
  @OptionGroup() var options: CommonOptions

  func run() async throws {
    let parsed = try OptionParser(
      requires: [.archive],
      options: options,
      command: Self.configuration,
      scheme: scheme,
      user: user,
      apiKey: apiKey,
      apiIssuer: apiIssuer,
      platform: platform
    )

    try await Self.upload(parsed: parsed)
  }

  static func upload(parsed: OptionParser) async throws {
    parsed.log("Uploading \(parsed.versionTag) to Apple Connect.")
    let xcrun = XCRunRunner(parsed: parsed)
    let uploadResult: Runner.Session
    if parsed.apiKey.isEmpty {
      // use username & password
      uploadResult = xcrun.run([
        "altool", "--upload-app", "--username", parsed.user, "--password", "@keychain:AC_PASSWORD",
        "--file", parsed.exportedIPAURL.path, "--output-format", "json", "--type", parsed.platform,
      ])
    } else {
      // use api key and issuer
      uploadResult = xcrun.run([
        "altool", "--upload-app", "--apiIssuer", parsed.apiIssuer, "--apiKey", parsed.apiKey,
        "--file", parsed.exportedIPAURL.path, "--output-format", "json", "--type", parsed.platform,
      ])
    }

    try await uploadResult.throwIfFailed(UploadRunnerError.uploadingFailed)

    parsed.log("Finished uploading.")
    let output = await uploadResult.stdout.string
    do {
      try output.write(to: parsed.uploadingReceiptURL, atomically: true, encoding: .utf8)
    } catch {
      throw UploadError.savingUploadReceiptFailed(error)
    }

    let receipt: UploadReceipt
    do {
      let decoder = JSONDecoder()
      decoder.keyDecodingStrategy = .dashCase
      receipt = try decoder.decode(UploadReceipt.self, from: output.data(using: .utf8)!)
    } catch {
      throw UploadError.decodingUploadReceiptFailed(error)
    }

    guard receipt.productErrors.isEmpty else {
      throw UploadError.uploadingFailedWithErrors(receipt.productErrors)
    }

    parsed.log("Tagging.")
    let git = GitRunner()
    let tagResult = git.run([
      "tag", parsed.versionTag, "-m", "Uploaded with \(CommandLine.name)",
    ])
    try await tagResult.throwIfFailed(GeneralError.taggingFailed)

  }
}

struct UploadReceiptError: Codable, Sendable {
  let code: Int
  let message: String
  let underlyingErrors: [UploadReceiptError]
  let userInfo: [String: String]?
}
struct UploadReceipt: Codable {
  let osVersion: String
  let toolPath: String
  let toolVersion: String
  let productErrors: [UploadReceiptError]
}

let testReceipt = #"""
  {
    "os-version" : "Version 15.5 (Build 24F74)",
    "product-errors" : [
      {
        "code" : 409,
        "message" : "Validation failed",
        "underlying-errors" : [
          {
            "code" : -19241,
            "message" : "Validation failed",
            "underlying-errors" : [

            ],
            "user-info" : {
              "NSLocalizedDescription" : "Validation failed",
              "NSLocalizedFailureReason" : "Missing required icon file. The bundle does not contain an app icon for iPhone / iPod Touch of exactly '120x120' pixels, in .png format for iOS versions >= 10.0. To support older versions of iOS, the icon may be required in the bundle outside of an asset catalog. Make sure the Info.plist file includes appropriate entries referencing the file. See https://developer.apple.com/documentation/bundleresources/information_property_list/user_interface.",
              "code" : "STATE_ERROR.VALIDATION_ERROR",
              "detail" : "Missing required icon file. The bundle does not contain an app icon for iPhone / iPod Touch of exactly '120x120' pixels, in .png format for iOS versions >= 10.0. To support older versions of iOS, the icon may be required in the bundle outside of an asset catalog. Make sure the Info.plist file includes appropriate entries referencing the file. See https://developer.apple.com/documentation/bundleresources/information_property_list/user_interface.",
              "id" : "80d42b8f-1bc9-4ff1-8ff9-1dba4d15249c",
              "status" : "409",
              "title" : "Validation failed"
            }
          }
        ],
        "user-info" : {
          "NSLocalizedDescription" : "Validation failed",
          "NSLocalizedFailureReason" : "Missing required icon file. The bundle does not contain an app icon for iPhone / iPod Touch of exactly '120x120' pixels, in .png format for iOS versions >= 10.0. To support older versions of iOS, the icon may be required in the bundle outside of an asset catalog. Make sure the Info.plist file includes appropriate entries referencing the file. See https://developer.apple.com/documentation/bundleresources/information_property_list/user_interface. (ID: 80d42b8f-1bc9-4ff1-8ff9-1dba4d15249c)",
          "NSUnderlyingError" : "Error Domain=IrisAPI Code=-19241 \"Validation failed\" UserInfo={status=409, detail=Missing required icon file. The bundle does not contain an app icon for iPhone / iPod Touch of exactly '120x120' pixels, in .png format for iOS versions >= 10.0. To support older versions of iOS, the icon may be required in the bundle outside of an asset catalog. Make sure the Info.plist file includes appropriate entries referencing the file. See https://developer.apple.com/documentation/bundleresources/information_property_list/user_interface., id=80d42b8f-1bc9-4ff1-8ff9-1dba4d15249c, code=STATE_ERROR.VALIDATION_ERROR, title=Validation failed, NSLocalizedFailureReason=Missing required icon file. The bundle does not contain an app icon for iPhone / iPod Touch of exactly '120x120' pixels, in .png format for iOS versions >= 10.0. To support older versions of iOS, the icon may be required in the bundle outside of an asset catalog. Make sure the Info.plist file includes appropriate entries referencing the file. See https://developer.apple.com/documentation/bundleresources/information_property_list/user_interface., NSLocalizedDescription=Validation failed}",
          "iris-code" : "STATE_ERROR.VALIDATION_ERROR"
        }
      },
      {
        "code" : 409,
        "message" : "Validation failed",
        "underlying-errors" : [
          {
            "code" : -19241,
            "message" : "Validation failed",
            "underlying-errors" : [

            ],
            "user-info" : {
              "NSLocalizedDescription" : "Validation failed",
              "NSLocalizedFailureReason" : "Missing required icon file. The bundle does not contain an app icon for iPad of exactly '152x152' pixels, in .png format for iOS versions >= 10.0. To support older operating systems, the icon may be required in the bundle outside of an asset catalog. Make sure the Info.plist file includes appropriate entries referencing the file. See https://developer.apple.com/documentation/bundleresources/information_property_list/user_interface.",
              "code" : "STATE_ERROR.VALIDATION_ERROR",
              "detail" : "Missing required icon file. The bundle does not contain an app icon for iPad of exactly '152x152' pixels, in .png format for iOS versions >= 10.0. To support older operating systems, the icon may be required in the bundle outside of an asset catalog. Make sure the Info.plist file includes appropriate entries referencing the file. See https://developer.apple.com/documentation/bundleresources/information_property_list/user_interface.",
              "id" : "8afcc144-23e0-4d6f-a085-85ffb39eff08",
              "status" : "409",
              "title" : "Validation failed"
            }
          }
        ],
        "user-info" : {
          "NSLocalizedDescription" : "Validation failed",
          "NSLocalizedFailureReason" : "Missing required icon file. The bundle does not contain an app icon for iPad of exactly '152x152' pixels, in .png format for iOS versions >= 10.0. To support older operating systems, the icon may be required in the bundle outside of an asset catalog. Make sure the Info.plist file includes appropriate entries referencing the file. See https://developer.apple.com/documentation/bundleresources/information_property_list/user_interface. (ID: 8afcc144-23e0-4d6f-a085-85ffb39eff08)",
          "NSUnderlyingError" : "Error Domain=IrisAPI Code=-19241 \"Validation failed\" UserInfo={status=409, detail=Missing required icon file. The bundle does not contain an app icon for iPad of exactly '152x152' pixels, in .png format for iOS versions >= 10.0. To support older operating systems, the icon may be required in the bundle outside of an asset catalog. Make sure the Info.plist file includes appropriate entries referencing the file. See https://developer.apple.com/documentation/bundleresources/information_property_list/user_interface., id=8afcc144-23e0-4d6f-a085-85ffb39eff08, code=STATE_ERROR.VALIDATION_ERROR, title=Validation failed, NSLocalizedFailureReason=Missing required icon file. The bundle does not contain an app icon for iPad of exactly '152x152' pixels, in .png format for iOS versions >= 10.0. To support older operating systems, the icon may be required in the bundle outside of an asset catalog. Make sure the Info.plist file includes appropriate entries referencing the file. See https://developer.apple.com/documentation/bundleresources/information_property_list/user_interface., NSLocalizedDescription=Validation failed}",
          "iris-code" : "STATE_ERROR.VALIDATION_ERROR"
        }
      },
      {
        "code" : 409,
        "message" : "Validation failed",
        "underlying-errors" : [
          {
            "code" : -19241,
            "message" : "Validation failed",
            "underlying-errors" : [

            ],
            "user-info" : {
              "NSLocalizedDescription" : "Validation failed",
              "NSLocalizedFailureReason" : "Missing app icon. Include a large app icon as a 1024 by 1024 pixel PNG for the 'Any Appearance' image well in the asset catalog of apps built for iOS or iPadOS. Without this icon, apps can't be submitted for review. For details, visit: https://developer.apple.com/documentation/xcode/configuring-your-app-icon.",
              "code" : "STATE_ERROR.VALIDATION_ERROR",
              "detail" : "Missing app icon. Include a large app icon as a 1024 by 1024 pixel PNG for the 'Any Appearance' image well in the asset catalog of apps built for iOS or iPadOS. Without this icon, apps can't be submitted for review. For details, visit: https://developer.apple.com/documentation/xcode/configuring-your-app-icon.",
              "id" : "55941c41-3ff9-4ced-99ab-dc020f70aa64",
              "status" : "409",
              "title" : "Validation failed"
            }
          }
        ],
        "user-info" : {
          "NSLocalizedDescription" : "Validation failed",
          "NSLocalizedFailureReason" : "Missing app icon. Include a large app icon as a 1024 by 1024 pixel PNG for the 'Any Appearance' image well in the asset catalog of apps built for iOS or iPadOS. Without this icon, apps can't be submitted for review. For details, visit: https://developer.apple.com/documentation/xcode/configuring-your-app-icon. (ID: 55941c41-3ff9-4ced-99ab-dc020f70aa64)",
          "NSUnderlyingError" : "Error Domain=IrisAPI Code=-19241 \"Validation failed\" UserInfo={status=409, detail=Missing app icon. Include a large app icon as a 1024 by 1024 pixel PNG for the 'Any Appearance' image well in the asset catalog of apps built for iOS or iPadOS. Without this icon, apps can't be submitted for review. For details, visit: https://developer.apple.com/documentation/xcode/configuring-your-app-icon., id=55941c41-3ff9-4ced-99ab-dc020f70aa64, code=STATE_ERROR.VALIDATION_ERROR, title=Validation failed, NSLocalizedFailureReason=Missing app icon. Include a large app icon as a 1024 by 1024 pixel PNG for the 'Any Appearance' image well in the asset catalog of apps built for iOS or iPadOS. Without this icon, apps can't be submitted for review. For details, visit: https://developer.apple.com/documentation/xcode/configuring-your-app-icon., NSLocalizedDescription=Validation failed}",
          "iris-code" : "STATE_ERROR.VALIDATION_ERROR"
        }
      }
    ],
    "tool-path" : "/Applications/Xcode-26.0.0-Beta.3.app/Contents/SharedFrameworks/ContentDelivery.framework/Versions/A/Resources",
    "tool-version" : "12.170.16 (170016)"
  }
  """#
