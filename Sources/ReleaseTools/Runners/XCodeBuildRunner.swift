// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 17/04/2019.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Runner

/// `xcodebuild` runner that mirrors the engine's logging preferences.
final class XCodeBuildRunner: Runner {
  /// Release context supplying logging preferences for this runner.
  let engine: ReleaseEngine

  /// Creates a runner bound to one release engine instance.
  init(engine: ReleaseEngine) {
    self.engine = engine
    super.init(command: "xcodebuild")
  }

  /// Runs an `xcodebuild` command using the engine's output policy.
  func run(_ arguments: [String]) -> Session {
    if engine.showCommands {
      engine.log("\n> xcodebuild \(arguments.joined(separator: " "))\n")
    }

    let mode: Runner.Output.Mode = engine.showOutput ? .both : .capture
    return run(arguments, stdoutMode: mode, stderrMode: mode)
  }
}
