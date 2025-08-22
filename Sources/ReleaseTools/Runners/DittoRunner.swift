// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 24/02/20.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Runner

class DittoRunner: Runner {
  let parsed: OptionParser
  init(parsed: OptionParser) {
    self.parsed = parsed
    super.init(command: "ditto")
  }

  func run(_ arguments: [String]) -> Session {
    if parsed.showCommands {
      parsed.log("ditto " + arguments.joined(separator: " "))
    }

    let mode: Runner.Output.Mode = parsed.showOutput ? .both : .capture
    return run(arguments, stdoutMode: mode, stderrMode: mode)
  }

  func zip(_ url: URL, as zipURL: URL) -> Session {
    parsed.log("Compressing \(url.lastPathComponent) to \(zipURL.path).")
    return run(["-c", "-k", "--sequesterRsrc", "--keepParent", url.path, zipURL.path])
  }
}
