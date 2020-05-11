// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 17/04/2019.
//  All code (c) 2019 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation

enum ExportError: Error {
    case exportFailed(_ output: String)
    case writingOptionsFailed(_ output: Error)

    public var description: String {
        switch self {
            case .exportFailed(let output): return "Exporting failed.\n\(output)"
            case .writingOptionsFailed(let error): return "Writing export options file failed.\n\(error)"
        }
    }
}

struct ExportCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "export",
        abstract: "Export an executable from the output of the archive command."
    )

    @Flag(help: "Export for distribution outside of the appstore.") var distribution: Bool
    @OptionGroup() var scheme: SchemeOption
    @OptionGroup() var platform: PlatformOption
    @OptionGroup() var options: CommonOptions

    func run() throws {
        let parsed = try OptionParser(
            options: options,
            command: Self.configuration,
            scheme: scheme,
            platform: platform
        )

        parsed.log("Generating export options for \(distribution ? "direct" : "appstore") distribution.")
        do {
            let options = [
                "iCloudContainerEnvironment": "Production",
                "signingStyle": "automatic",
                "method": distribution ? "developer-id" : "app-store"
                ]
            let data = try PropertyListSerialization.data(fromPropertyList: options, format: .xml, options: 0)
            try data.write(to: parsed.exportOptionsURL)
        } catch {
            throw ExportError.writingOptionsFailed(error)
        }

        parsed.log("Exporting \(parsed.scheme).")
        let xcode = XCodeBuildRunner(parsed: parsed)
        try? FileManager.default.removeItem(at: parsed.exportURL)
        let result = try xcode.run(arguments: ["-exportArchive", "-archivePath", parsed.archiveURL.path, "-exportPath", parsed.exportURL.path, "-exportOptionsPlist", parsed.exportOptionsURL.path, "-allowProvisioningUpdates"])
        if result.status != 0 {
            throw ExportError.exportFailed(result.stderr)
        }
    }
}
