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
}
