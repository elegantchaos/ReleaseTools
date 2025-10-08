// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 19/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Runner

class GitRunner: Runner {
  init(environment: [String: String] = ProcessInfo.processInfo.environment) {
    super.init(command: "git", environment: environment)
  }

  /// Get the HEAD commit SHA
  /// - Returns: The full commit SHA as a string
  /// - Throws: UpdateBuildError if the command fails or the output cannot be parsed
  func headCommit() async throws -> String {
    let commitResult = run(["rev-parse", "HEAD"])
    let commitOutput = await commitResult.stdout.string
    let commitState = await commitResult.waitUntilExit()
    guard case .succeeded = commitState else {
      throw UpdateBuildError.gettingCommitFailed
    }
    guard let commit = commitOutput.split(separator: "\n").first else {
      throw UpdateBuildError.parsingCommitFailed
    }
    return commit.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
