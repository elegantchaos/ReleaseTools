// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 25/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

import protocol ArgumentParser.AsyncParsableCommand

enum InstallError: Error {
  case couldntWriteStub

  public var description: String {
    switch self {
    case .couldntWriteStub: return "Couldn't write rt stub to \(InstallCommand.stubPath.path)."
    }
  }
}

struct InstallCommand: AsyncParsableCommand {
  static var configuration: CommandConfiguration {
    CommandConfiguration(
      commandName: "install",
      abstract: "Install a stub in /usr/local/bin to allow you to invoke the tool more easily."
    )
  }

  @OptionGroup() var options: CommonOptions

  static let stub = """
    #!/bin/sh

    MODE=debug
    PRODUCT=.build/$MODE/rt

    if [[ ! -e "$PRODUCT" ]]
    then
    swift build --product ReleaseTools --configuration $MODE
    fi

    "$PRODUCT" "$@"
    """

  static let stubPath = URL(fileURLWithPath: "/usr/local/bin/rt")

  func run() throws {
    do {
      let parsed = try OptionParser(
        options: options,
        command: Self.configuration
      )

      parsed.log("Installing stub to \(InstallCommand.stubPath.path).")
      try InstallCommand.stub.write(to: InstallCommand.stubPath, atomically: true, encoding: .utf8)
    } catch {
      throw InstallError.couldntWriteStub
    }
  }
}
