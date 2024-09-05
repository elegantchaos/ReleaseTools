// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 17/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Runner

class XCodeBuildRunner: Runner {
  let parsed: OptionParser

  init(parsed: OptionParser) {
    self.parsed = parsed
    super.init(command: "xcodebuild")
  }

  func schemes(workspace: String) async throws -> [String] {
    let result = run(["-workspace", workspace, "-list", "-json"])
    let output = await Data(result.stdout)
    for await state in result.state {
      if state == .succeeded {
        let decoder = JSONDecoder()
        let schemes = try decoder.decode(SchemesSpec.self, from: output)
        return schemes.workspace.schemes
      } else {
        print(await result.stderr)
      }
    }

    return []
  }

  func run(_ arguments: [String]) -> Session {
    if parsed.showOutput {
      parsed.log("\n> xcodebuild \(arguments.joined(separator: " "))\n")
    }

    let mode: ProcessStream.Mode = parsed.showOutput ? .both : .capture
    return run(arguments, stdoutMode: mode, stderrMode: mode)
  }
}
