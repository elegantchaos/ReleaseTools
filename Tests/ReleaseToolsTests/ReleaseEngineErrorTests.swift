// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 21/10/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Testing

@testable import ReleaseTools

/// Verifies user-facing descriptions of release workflow failures.
struct ReleaseEngineErrorTests {
  /// Duplicate-tag diagnostics name the existing tag without exposing the build metadata structure.
  @Test func describesExistingVersionTag() {
    let info = ReleaseEngine.BuildInfo(
      build: 267,
      commit: "d239b36e9123f9430d95ebbbd15a49798b3617fc",
      version: "1.0.0"
    )

    let error = ReleaseEngine.Error.versionTagAlreadyExists(info)
    #expect(error.localizedDescription == "A version tag already exists at HEAD: v1.0.0-267.")
  }
}
