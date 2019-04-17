// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 17/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Arguments

class CompressCommand: Command {
    override var name: String { return "archive" }

    override var usage: String { return "release compress" }

    override func run(arguments: Arguments) throws -> ReturnCode {
        return .ok
        /*
 BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" .build/export/Bookish.app/Contents/Info.plist)
 VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" .build/export/Bookish.app/Contents/Info.plist)
 echo $BUILD
 echo $VERSION
 ditto -c -k --sequesterRsrc --keepParent ".build/export/Bookish.app/" "Dependencies/Website/updates/bookish-$VERSION-$BUILD.zip"
 rm -rf Dependencies/Website/updates/.tmp
*/
        
    }
}
