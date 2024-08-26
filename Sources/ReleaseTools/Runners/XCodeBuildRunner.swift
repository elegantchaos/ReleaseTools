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

  func schemes(workspace: String) throws -> [String] {
    let result = try sync(arguments: ["-workspace", workspace, "-list", "-json"])
    if result.status == 0, let data = result.stdout.data(using: .utf8) {
      let decoder = JSONDecoder()
      let schemes = try decoder.decode(SchemesSpec.self, from: data)
      return schemes.workspace.schemes
    } else {
      print(result.stderr)
      return []
    }
  }

  func run(arguments: [String]) throws -> Runner.Result {
    if parsed.showOutput {
      parsed.log("xcodebuild " + arguments.joined(separator: " "))
    }

    let mode = parsed.showOutput ? Runner.Mode.tee : Runner.Mode.capture
    return try sync(arguments: arguments, stdoutMode: mode, stderrMode: mode)
  }
}
