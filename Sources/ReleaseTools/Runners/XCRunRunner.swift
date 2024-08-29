// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/02/20.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Runner

class XCRunRunner: Runner {
  let parsed: OptionParser

  init(parsed: OptionParser) {
    self.parsed = parsed
    super.init(command: "xcrun")
  }

  func run(_ arguments: [String]) throws -> RunningProcess {
    if parsed.showOutput {
      parsed.log("xcrun " + arguments.joined(separator: " "))
    }

    let mode: Runner.Mode = parsed.showOutput ? .both : .capture
    return try run(arguments, stdoutMode: mode, stderrMode: mode)
  }
}
