// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/02/2020.
//  Copyright © 2020 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Runner

/// `ditto` runner used for archive compression.
final class DittoRunner: Runner {
  let engine: ReleaseEngine

  /// Creates a runner bound to one release engine instance.
  init(engine: ReleaseEngine) {
    self.engine = engine
    super.init(command: "ditto")
  }

  /// Runs a `ditto` command using the engine's output policy.
  func run(_ arguments: [String]) -> Session {
    if engine.showCommands {
      engine.log("ditto " + arguments.joined(separator: " "))
    }

    let mode: Runner.Output.Mode = engine.showOutput ? .both : .capture
    return run(arguments, stdoutMode: mode, stderrMode: mode)
  }

  /// Compresses a bundle into a zip archive using `ditto`.
  func zip(_ url: URL, as zipURL: URL) -> Session {
    engine.log("Compressing \(url.lastPathComponent) to \(zipURL.path).")
    return run(["-c", "-k", "--sequesterRsrc", "--keepParent", url.path, zipURL.path])
  }
}
