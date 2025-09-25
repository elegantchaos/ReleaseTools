// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 11/02/21.
//  All code (c) 2021 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Files
import Foundation
import Resources

struct BootstrapCommand: AsyncParsableCommand {
  enum Error: Swift.Error {
    case couldntCopyConfigs(error: Swift.Error)

    public var description: String {
      switch self {
        case .couldntCopyConfigs(let error): return "Couldn't copy files \(error)."
      }
    }
  }

  static var configuration: CommandConfiguration {
    CommandConfiguration(
      commandName: "bootstrap",
      abstract: "Copy script files into the current project."
    )
  }

  @OptionGroup() var options: CommonOptions

  func run() async throws {
    do {
      let locations = FileManager.default.locations
      let localScriptsFolder = locations.current.folder("Extras/Scripts")

      let parsed = try OptionParser(
        options: options,
        command: Self.configuration
      )

      parsed.log("Copying scripts to \(localScriptsFolder).")
      try Resources.scriptsPath.merge(into: localScriptsFolder)

    } catch {
      throw Error.couldntCopyConfigs(error: error)
    }
  }
}
