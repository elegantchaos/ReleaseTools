// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 03/09/24.
//  All code (c) 2024 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation
import PackagePlugin

@main struct ReleaseToolsPlugin: CommandPlugin {
  func run(tool: String, arguments: [String], context: PackagePlugin.PluginContext, cwd: URL) async throws -> String {
    let tool = try context.tool(named: tool)

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
    let output = try await run(
      tool: "ActionBuilderTool", arguments: arguments, context: context, cwd: context.package.directoryURL)

    Diagnostics.remark(output)

  }
}
