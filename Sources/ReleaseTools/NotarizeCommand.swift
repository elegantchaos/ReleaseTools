
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 03/06/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import CommandShell

extension Result {
//    static let commitFailed = Result(250, "Failed to commit the appcast feed and updates.")
//    static let pushFailed = Result(251, "Failed to push the appcast feed and updates.")
}

class NotarizeCommand: Command {
    override var description: Command.Description {
        return Description(
            name: "notarize",
            help: "Request notarization of the archived app.",
            usage: [""]
        )
    }
    
    override func run(shell: Shell) throws -> Result {
        guard let archive = XcodeArchive(url: URL(fileURLWithPath: ArchiveCommand.archivePath)) else {
            return .infoUnreadable
        }

        let xcrun = XcodeRunner()
        
        let bundle = "com.elegantchaos.bookish.mac"
        let user = "company@elegantchaos.com"
        let password = "@keychain:AC_PASSWORD"
        
        let result = try xcrun.sync(arguments: ["altool", "-notarize-app", "-primary-bundle-id", bundle, "--username", user, "--password", password, "--file", ])
        if result.status != 0 {
            return Result.commitFailed.adding(runnerResult: result)
        }

        //        let git = GitRunner()
//        let appcastRepo = try shell.arguments.expectedOption("repo")
//        git.cwd = URL(fileURLWithPath: appcastRepo)
//
//        guard let archive = XcodeArchive(url: URL(fileURLWithPath: ArchiveCommand.archivePath)) else {
//            return .infoUnreadable
//        }
//
//        shell.log("Committing updates.")
//        let message = "v\(archive.version), build \(archive.build)"
//        let result = try git.sync(arguments: ["commit", "-a", "-m", message])
//        if result.status != 0 {
//            return Result.commitFailed.adding(runnerResult: result)
//        }
//
//        shell.log("Pushing updates.")
//        let pushResult = try git.sync(arguments: ["push"])
//        if pushResult.status != 0 {
//            return Result.pushFailed.adding(runnerResult: pushResult)
//        }
        
        return .ok
    }
}


// xcrun altool --notarize-app --primary-bundle-id "com.elegantchaos.bookish.mac" --username "company@elegantchaos.com" --password "@keychain:AC_PASSWORD" --file "Dependencies/Website/updates/bookish-$VERSION-$BUILD.zip"

