// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 17/04/2019.
//  Copyright © 2019 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Runner

/// `xcodebuild` runner that mirrors the engine's logging preferences.
final class XCodeBuildRunner: Runner {
  let engine: ReleaseEngine

  /// Creates a runner bound to one release engine instance.
  init(engine: ReleaseEngine) {
    self.engine = engine
    super.init(command: "xcodebuild")
  }

  /// Returns the schemes exposed by an Xcode workspace.
  func schemes(workspace: String) async throws -> [String] {
    let result = run(["-workspace", workspace, "-list", "-json"])
    let output = await result.stdout.data
    for await state in result.state {
      if state == .succeeded {
        let decoder = JSONDecoder()
        let schemes = try decoder.decode(SchemesSpec.self, from: output)
        return schemes.workspace.schemes
      } else {
        print(await result.stderr.string)
      }
    }

    return []
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
