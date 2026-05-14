// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 07/04/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import Foundation

/// Error used for argument and workflow validation failures in `rt validate`.
struct CLIError: Error, CustomStringConvertible {
  let message: String

  var description: String { message }
}

/// Control-flow signals used to stop normal validation execution.
enum ValidateSignal: Error {
  case helpRequested
}

/// Minimal target metadata decoded from `swift package dump-package`.
struct TargetInfo: Decodable {
  let name: String
  let type: String
}

/// Minimal package metadata needed to decide whether a package has test targets.
struct PackageDescription: Decodable {
  let targets: [TargetInfo]
}

/// Derived filesystem and environment paths for a validation run.
struct ToolingPaths {
  let verifyRoot: String
  let derivedDataPath: String
  let env: [String: String]
}

/// Output verbosity modes supported by `rt validate`.
enum ValidateOutputMode: String {
  case filtered
  case quiet
  case raw
}

/// Parsed validation configuration derived from command-line arguments.
struct Config {
  let clean: Bool
  let target: String?
  let workspaceOverride: String?
  let projectOverride: String?
  let schemes: [String]
  let destinations: [String]
  let runXcodeTests: Bool
  let testDestinations: [String]
  let packageDirsOverride: [String]?
  let recursivePackageDiscovery: Bool
  let swiftPMDisableSandbox: Bool
  let outputMode: ValidateOutputMode
}

/// Result status for each recorded validation step.
enum ValidationStepStatus: String {
  case pass = "PASS"
  case fail = "FAIL"
  case skip = "SKIP"
}

/// Summary record for one validation step in the final report.
struct ValidationStepRecord {
  let summary: String
  let status: ValidationStepStatus
  let warningsPresent: Bool
  let logPath: String?
}

/// Captured output and exit information for one validation subprocess.
struct ValidationCommandResult {
  let status: Int32
  let output: String
  let warningsPresent: Bool
}

/// Thread-safe aggregation state for streamed validation output.
final class ValidationStreamState: @unchecked Sendable {
  private let lock = NSLock()
  private var combinedData = Data()
  private var bufferedTerminalText = ""
  private var sawEOF = false

  /// Appends raw output to the combined buffer and filtered line buffer.
  func append(_ data: Data, outputMode: ValidateOutputMode) {
    lock.lock()
    defer { lock.unlock() }

    combinedData.append(data)

    guard outputMode == .filtered, let chunk = String(data: data, encoding: .utf8), !chunk.isEmpty else { return }
    bufferedTerminalText += chunk
  }

  /// Returns complete filtered lines accumulated since the last drain.
  func drainFilteredLines() -> [String] {
    lock.lock()
    defer { lock.unlock() }

    let lines = bufferedTerminalText.components(separatedBy: .newlines)
    bufferedTerminalText = lines.last ?? ""
    return lines.dropLast().compactMap(filteredValidationLine)
  }

  /// Returns the final trailing filtered line after a stream completes.
  func flushTrailingFilteredLine() -> String? {
    lock.lock()
    defer { lock.unlock() }

    defer { bufferedTerminalText = "" }
    return filteredValidationLine(bufferedTerminalText)
  }

  /// Returns the full combined process output as a string.
  func outputString() -> String {
    lock.lock()
    defer { lock.unlock() }
    return String(data: combinedData, encoding: .utf8) ?? ""
  }

  /// Marks the stream as complete, returning `true` only on the first EOF.
  func markEOF() -> Bool {
    lock.lock()
    defer { lock.unlock() }

    guard !sawEOF else { return false }
    sawEOF = true
    return true
  }
}
