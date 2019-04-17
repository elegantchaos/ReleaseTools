// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 17/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Arguments
import Runner

class ArchiveCommand: Command {
    override var name: String { return "archive" }

    func defaultWorkspace() -> String? {
        let url = URL(fileURLWithPath: ".")
        if let contents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [], options: [.skipsPackageDescendants, .skipsSubdirectoryDescendants, .skipsHiddenFiles]) {
            for item in contents {
                if item.pathExtension == "xcworkspace" {
                    return item.lastPathComponent
                }
            }
        }
        return nil
    }
        
    override func run(arguments: Arguments) -> ReturnCode {
        
//        echo "Archiving"
//        xcodebuild -workspace Bookish.xcworkspace -scheme BookishMac archive -archivePath "$PWD/.build/archive" > "$PWD/.build/archive.log"
        
        let xcode = Runner(for: URL(fileURLWithPath: "/usr/bin/xcodebuild"))
        guard let workspace = defaultWorkspace() else {
            return .badArguments
        }

        do {
            let result = try xcode.sync(arguments: ["-workspace", workspace, "-scheme", "BookishMac", "archive", "-archivePath", ".build/archive"])
            if result.status == 0 {
                return .ok
            } else {
                print(result.stderr)
                return .archiveFailed
            }
        } catch {
            return .runFailed
        }
    }
}
