// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 17/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Arguments
import CommandShell

class ExportCommand: Command {
    override var name: String { return "export" }
    
    override var usage: String { return "release export" }

    override func run(arguments: Arguments) throws -> ReturnCode {
        
        /*
 echo "Exporting"
 rm -rf "$PWD/.build/export"
 xcodebuild -exportArchive -archivePath "$PWD/.build/archive.xcarchive" -exportPath "$PWD/.build/export" -exportOptionsPlist "$PWD/Sources/BookishMac/Resources/Export Options.plist" -allowProvisioningUpdates

 */
        
        return .ok
    }
}
