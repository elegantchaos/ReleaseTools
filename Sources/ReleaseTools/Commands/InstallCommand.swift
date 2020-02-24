// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 25/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import CommandShell
import Foundation

extension Result {
    static let couldntWriteStub = Result(800, "Couldn't write rt stub to \(InstallCommand.stubPath.path).")
}

class InstallCommand: Command {
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
    
    override var description: Command.Description {
        return Description(name: "install", help: "Install a stub in /usr/local/bin to allow you to invoke the tool more easily.", usage: [""])
    }

    override func run(shell: Shell) throws -> Result {
        do {
            shell.log("Installing stub to \(InstallCommand.stubPath.path).")
            try InstallCommand.stub.write(to: InstallCommand.stubPath, atomically: true, encoding: .utf8)
            return .ok
        } catch {
            return .couldntWriteStub
        }
    }
}
