// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 03/09/24.
//  All code (c) 2024 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import PackagePlugin

@main struct ReleaseToolsPlugin: CommandPlugin {
    
    func run(tool: PluginContext.Tool, arguments: [String], cwd: URL) async throws -> String {
        Diagnostics.remark("Running \(tool) \(arguments.joined(separator: " ")).")
        
        let outputPipe = Pipe()
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = tool.url
            process.arguments = arguments
            process.currentDirectoryURL = cwd
            
            process.standardOutput = outputPipe
            process.terminationHandler = { process in
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(
                    returning: String(decoding: data, as: UTF8.self)
                )
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    func performCommand(context: PackagePlugin.PluginContext, arguments: [String]) async throws {
        let tool = try context.tool(
            named: "ActionBuilderTool"
        )
        let output = try await run(
            tool: tool, arguments: arguments, cwd: context.package.directoryURL)
        
        Diagnostics.remark(output)
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

func runSync(tool: PluginContext.Tool, arguments: [String], cwd: URL) throws -> String {
    Diagnostics.remark("Running \(tool) \(arguments.joined(separator: " ")).")
    
    let process = Process()
    process.executableURL = tool.url
    process.arguments = arguments
    process.currentDirectoryURL = cwd
    
    let outputPipe = Pipe()
    process.standardOutput = outputPipe
    try process.run()
    process.waitUntilExit()
    
    let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
    return String(decoding: data, as: UTF8.self)
}

extension ReleaseToolsPlugin: XcodeCommandPlugin {
    func performCommand(context: XcodePluginContext, arguments: [String]) throws {
        let tool = try context.tool(
            named: "ActionBuilderTool"
        )
        
        let output = try runSync(tool: tool, arguments: arguments, cwd: context.xcodeProject.directoryURL)
        Diagnostics.remark(output)
    }
}
#endif
