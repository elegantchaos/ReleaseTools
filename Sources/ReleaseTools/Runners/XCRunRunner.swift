// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/02/2020.
//  Copyright © 2020 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Runner

/// `xcrun` runner that mirrors the engine's logging preferences.
final class XCRunRunner: Runner {
  let engine: ReleaseEngine

  /// Creates a runner bound to one release engine instance.
  init(engine: ReleaseEngine) {
    self.engine = engine
    super.init(command: "xcrun")
  }

  /// Runs an `xcrun` command using the engine's output policy.
  func run(_ arguments: [String]) -> Session {
    if engine.showCommands {
      engine.log("xcrun " + arguments.joined(separator: " "))
    }

    let mode: Runner.Output.Mode = engine.showOutput ? .both : .capture
    return run(arguments, stdoutMode: mode, stderrMode: mode)
  }
}
