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
                        PRODUCT=.build/$MODE/ReleaseTools

                        if [[ ! -e "$PRODUCT" ]]
                        then
                        swift build --product ReleaseTools --configuration $MODE
                        fi

                        "$PRODUCT" "$@"
                        """
    
    static let stubPath = URL(fileURLWithPath: "/usr/local/bin/rt")
    
    override var name: String { return "install" }
    
    override var usage: [String] { return [""]}
    override func run(shell: Shell) throws -> Result {
        do {
            try InstallCommand.stub.write(to: InstallCommand.stubPath, atomically: true, encoding: .utf8)
            return .ok
        } catch {
            return .couldntWriteStub
        }
    }
}
