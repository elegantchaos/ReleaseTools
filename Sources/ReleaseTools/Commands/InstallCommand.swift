// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 25/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import CommandShell
import ArgumentParser
import Foundation

enum InstallError: Error {
    case couldntWriteStub
    
    public var description: String {
        switch self {
            case .couldntWriteStub: return "Couldn't write rt stub to \(InstallCommand.stubPath.path)."
        }
    }
}

struct InstallCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Install a stub in /usr/local/bin to allow you to invoke the tool more easily."
    )
    
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
            shell.log("Installing stub to \(InstallCommand.stubPath.path).")
            try InstallCommand.stub.write(to: InstallCommand.stubPath, atomically: true, encoding: .utf8)
        } catch {
            throw InstallError.couldntWriteStub
        }
    }
}
