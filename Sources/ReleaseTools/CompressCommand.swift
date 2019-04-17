// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 17/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import Arguments
import CommandShell
import Runner

extension Result {
    static let infoUnreadable = Result(400, "Couldn't read archive info.plist.")
    static let infoMissing = Result(401, "Archive info.plist doesn't have all the information we need.")
}

class CompressCommand: Command {
    override var name: String { return "compress" }

    override var usage: String { return "release compress --to=<to> --latest=<latest>" }

    override func run(shell: Shell) throws -> Result {
        let archiveURL = URL(fileURLWithPath: ArchiveCommand.archivePath).appendingPathComponent("Info.plist")
        let data = try Data(contentsOf: archiveURL)
        guard let info = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String:Any] else {
            return .infoUnreadable
        }

        guard
            let appInfo = info["ApplicationProperties"] as? [String:Any],
            let appPath = appInfo["ApplicationPath"] as? String,
            let build = appInfo["CFBundleVersion"] as? String,
            let version = appInfo["CFBundleShortVersionString"] as? String
            else {
            return .infoMissing
        }

        let appName = URL(fileURLWithPath: appPath).lastPathComponent
        let shortAppName = URL(fileURLWithPath: appPath).deletingPathExtension().lastPathComponent
        let exportedAppPath = URL(fileURLWithPath: ExportCommand.exportPath).appendingPathComponent(appName)
        let ditto = Runner(for: URL(fileURLWithPath: "/usr/bin/ditto"))
        let archiveName = "\(shortAppName.lowercased())-\(version)-\(build).zip"
        let archiveFolder = try shell.arguments.expectedOption("to")
        let destination = URL(fileURLWithPath: archiveFolder).appendingPathComponent(archiveName)
        
        shell.log("Compressing \(appName) to \(archiveFolder) as \(archiveName).")
        let result = try ditto.sync(arguments: ["-c", "-k", "--sequesterRsrc", "--keepParent", exportedAppPath.path, destination.path])
        if result.status != 0 {
            var returnResult = Result.exportFailed
            returnResult.supplementary = result.stderr
            return returnResult
        }
        
        let latestFolder = try shell.arguments.expectedOption("latest")
        let latestZip = URL(fileURLWithPath: latestFolder).appendingPathComponent("\(shortAppName.lowercased()).zip")
        try FileManager.default.copyItem(at: destination, to: latestZip)

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
