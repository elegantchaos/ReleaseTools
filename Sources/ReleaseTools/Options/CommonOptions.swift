// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/04/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser

/// Shared flags used by most release commands.
struct CommonOptions: ParsableArguments {
  /// Whether to echo external command lines.
  @Flag(help: "Show the external commands that we're executing.") var showCommands = false

  /// Whether to display external command output.
  @Flag(help: "Show the output from the external commands that we execute.") var showOutput = false

  /// Whether to emit additional diagnostic messages.
  @Flag(help: "Show extra logging.") var verbose = false

  /// Workspace path supplied instead of repository discovery.
  @Option(help: "The workspace we're operating on.")
  var workspace: String?
}
