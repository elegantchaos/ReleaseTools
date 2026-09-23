// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/04/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser

/// Shared flags used by most release commands.
struct CommonOptions: ParsableArguments {
  @Flag(help: "Show the external commands that we're executing.") var showCommands = false
  @Flag(help: "Show the output from the external commands that we execute.") var showOutput = false
  @Flag(help: "Show extra logging.") var verbose = false
  @Option(help: "The workspace we're operating on.")
  var workspace: String?
}
