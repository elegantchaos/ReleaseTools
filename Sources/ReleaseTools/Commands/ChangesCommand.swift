// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 30/03/2020.
//  All code (c) 2020 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import AppKit
import ArgumentParser
import Foundation

enum ChangesError: Error {
  case couldntFetchLog(error: Error)

  public var description: String {
    switch self {
    case .couldntFetchLog(let error): return "Couldn't fetch the git log.\n\(error)"
    }
  }
}

struct ChangesCommand: AsyncParsableCommand {
  static var configuration: CommandConfiguration {
    CommandConfiguration(
      commandName: "changes",
      abstract: "Show the change log since a previous version."
    )
  }

  @Argument(help: "An older version/commit to compare against.") var version: String
  @Argument(help: "A newer version/commit to compare against the older version. Defaults to HEAD.")
  var other: String?
  @OptionGroup() var common: CommonOptions

  func run() async throws {
    let parsed = try OptionParser(
      requires: [.workspace],
      options: common,
      command: Self.configuration,
      setDefaultPlatform: false
    )

    let git = GitRunner()
    var arguments = ["log", "--pretty=- %s %b"]
    if let other = other {
      arguments.append("\(version)..\(other)")
    } else {
      arguments.append("\(version)..HEAD")
    }

    do {
      let result = try git.run(arguments)
      let output = await String(result.stdout)
      try output.write(to: parsed.changesURL, atomically: true, encoding: .utf8)
      NSWorkspace.shared.open(parsed.changesURL)
    } catch {
      throw ChangesError.couldntFetchLog(error: error)
    }

  }
}
