// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 26/02/2026.
//  All code (c) 2026 - present day, Elegant Chaos Limited.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ArgumentParser
import Foundation

struct ValidateCommand: AsyncParsableCommand {
  static var configuration: CommandConfiguration {
    CommandConfiguration(
      commandName: "validate",
      abstract: "Run the standard validation flow for a Swift repository."
    )
  }

  @Argument(parsing: .captureForPassthrough, help: "Arguments to pass to the validation flow.")
  var arguments: [String] = []

  mutating func run() async throws {
    do {
      try runValidationFlow(arguments)
    } catch ValidateSignal.helpRequested {
      usage()
    }
  }
}

struct CLIError: Error, CustomStringConvertible {
  let message: String
  var description: String { message }
}

enum ValidateSignal: Error {
  case helpRequested
}

struct TargetInfo: Decodable {
  let name: String
  let type: String
}

struct PackageDescription: Decodable {
  let targets: [TargetInfo]
}

func packageHasTestTargets(_ package: PackageDescription) -> Bool {
  package.targets.contains(where: { $0.type == "test" })
}

struct ToolingPaths {
  let cacheRoot: String?
  let verifyRoot: String
  let derivedDataPath: String?
  let env: [String: String]
}

enum ValidateOutputMode: String {
  case filtered
  case quiet
  case raw
}

struct Config {
  let clean: Bool
  let useCodexCaches: Bool
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

enum ValidationStepStatus: String {
  case pass = "PASS"
  case fail = "FAIL"
  case skip = "SKIP"
}

struct ValidationStepRecord {
  let summary: String
  let status: ValidationStepStatus
  let warningsPresent: Bool
  let logPath: String?
}

struct ValidationCommandResult {
  let status: Int32
  let output: String
  let warningsPresent: Bool
}

final class ValidationStreamState: @unchecked Sendable {
  private let lock = NSLock()
  private var combinedData = Data()
  private var bufferedTerminalText = ""
  private var sawEOF = false

  func append(_ data: Data, outputMode: ValidateOutputMode) {
    lock.lock()
    defer { lock.unlock() }

    combinedData.append(data)

    guard outputMode == .filtered, let chunk = String(data: data, encoding: .utf8), !chunk.isEmpty else { return }
    bufferedTerminalText += chunk
  }

  func drainFilteredLines() -> [String] {
    lock.lock()
    defer { lock.unlock() }

    let lines = bufferedTerminalText.components(separatedBy: .newlines)
    bufferedTerminalText = lines.last ?? ""
    return lines.dropLast().compactMap(filteredValidationLine)
  }

  func flushTrailingFilteredLine() -> String? {
    lock.lock()
    defer { lock.unlock() }

    defer { bufferedTerminalText = "" }
    return filteredValidationLine(bufferedTerminalText)
  }

  func outputString() -> String {
    lock.lock()
    defer { lock.unlock() }
    return String(data: combinedData, encoding: .utf8) ?? ""
  }

  func markEOF() -> Bool {
    lock.lock()
    defer { lock.unlock() }

    guard !sawEOF else { return false }
    sawEOF = true
    return true
  }
}

func usage() {
  print(
    """
    Usage:
      rt validate [options]
      rt validate --target <name> [options]

    Modes:
      default                      Comprehensive mode (format/lint changed Swift files + broad validation)
      --target <name>              Targeted validation mode

    Options:
      --target <name>              Target name for targeted validation mode
      --clean                      Remove cached validation logs and derived data before running checks
      --use-codex-caches           Force shared /tmp/codex-cache paths and cache environment overrides
      --workspace <path>           Explicit workspace path (absolute or repo-relative)
      --project <path>             Explicit project path (absolute or repo-relative)
      --schemes <csv>              Xcode schemes for broad validation (default: repo name)
      --destinations <csv>         Xcode build destinations (default: generic/platform=iOS,generic/platform=macOS)
      --run-xcode-tests            Also run xcodebuild test for test destinations
      --test-destinations <csv>    Xcode test destinations (default: platform=macOS)
      --package-dirs <csv>         Package directories for SwiftPM checks (absolute or repo-relative)
      --no-recursive-packages      Disable recursive Package.swift discovery
      --swiftpm-disable-sandbox    Disable SwiftPM's internal sandbox (opt-in fallback only)
      --output <mode>              Validation output mode: filtered, quiet, raw (default: filtered)
      --quiet                      Alias for --output quiet
      --raw                        Alias for --output raw
      --help                       Show help

    """)
}

func parseCSV(_ value: String?) -> [String] {
  guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
  return
    value
    .split(separator: ",")
    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    .filter { !$0.isEmpty }
}

func expandTilde(_ path: String) -> String {
  NSString(string: path).expandingTildeInPath
}

func sanitize(_ value: String) -> String {
  value.replacingOccurrences(of: "[^A-Za-z0-9]+", with: "_", options: .regularExpression)
}

func fileExists(_ path: String) -> Bool {
  FileManager.default.fileExists(atPath: path)
}

func isDirectory(_ path: String) -> Bool {
  var isDir: ObjCBool = false
  let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
  return exists && isDir.boolValue
}

func resolvePath(_ value: String, repoPath: String) -> String {
  let expanded = expandTilde(value)
  if expanded.hasPrefix("/") {
    return URL(fileURLWithPath: expanded).standardizedFileURL.path
  }
  return URL(fileURLWithPath: repoPath).appendingPathComponent(expanded).standardizedFileURL.path
}

func ensureDirectory(_ path: String) throws {
  try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
}

func commandString(_ executable: String, _ arguments: [String]) -> String {
  ([executable] + arguments).joined(separator: " ")
}

func run(_ executable: String, _ arguments: [String], cwd: String, environment: [String: String]) throws -> Int32 {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: executable)
  process.arguments = arguments
  process.currentDirectoryURL = URL(fileURLWithPath: cwd)

  var mergedEnv = ProcessInfo.processInfo.environment
  for (k, v) in environment { mergedEnv[k] = v }
  process.environment = mergedEnv

  process.standardOutput = FileHandle.standardOutput
  process.standardError = FileHandle.standardError

  print("+ " + commandString(executable, arguments))

  try process.run()
  process.waitUntilExit()

  if process.terminationStatus != 0 {
    throw CLIError(message: "Command failed with exit code \(process.terminationStatus): " + commandString(executable, arguments))
  }

  return process.terminationStatus
}

func capture(_ executable: String, _ arguments: [String], cwd: String, environment: [String: String]) throws -> (status: Int32, stdout: String, stderr: String) {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: executable)
  process.arguments = arguments
  process.currentDirectoryURL = URL(fileURLWithPath: cwd)

  var mergedEnv = ProcessInfo.processInfo.environment
  for (k, v) in environment { mergedEnv[k] = v }
  process.environment = mergedEnv

  let stdoutPipe = Pipe()
  let stderrPipe = Pipe()
  process.standardOutput = stdoutPipe
  process.standardError = stderrPipe

  try process.run()
  process.waitUntilExit()

  let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
  let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

  return (process.terminationStatus, stdout, stderr)
}

func stepBanner(_ title: String) {
  print("== \(title)")
}

func printCommandIdentity(_ executable: String, _ arguments: [String]) {
  print("+ " + commandString(executable, arguments))
}

func defaultLogPath(_ tools: ToolingPaths, _ name: String) -> String {
  "\(tools.verifyRoot)/\(sanitize(name)).log"
}

func filteredValidationLine(_ line: String) -> String? {
  let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
  guard !trimmed.isEmpty else { return nil }

  let suppressedPatterns = [
    "remark: compiled module was created by a different version of the compiler"
  ]

  if suppressedPatterns.contains(where: { trimmed.localizedCaseInsensitiveContains($0) }) {
    return nil
  }

  let visiblePatterns = [
    "error:",
    "warning:",
    "note:",
    "BUILD FAILED",
    "BUILD SUCCEEDED",
  ]

  return visiblePatterns.contains(where: { trimmed.localizedCaseInsensitiveContains($0) }) ? trimmed : nil
}

func containsValidationWarnings(_ output: String) -> Bool {
  output
    .split(whereSeparator: \.isNewline)
    .map(String.init)
    .contains(where: { filteredValidationLine($0)?.localizedCaseInsensitiveContains("warning:") == true })
}

func extractedFailureDiagnostics(_ output: String) -> [String] {
  let lines = output.split(whereSeparator: \.isNewline).map(String.init)

  guard let firstErrorIndex = lines.firstIndex(where: { $0.localizedCaseInsensitiveContains("error:") }) else {
    return lines.compactMap(filteredValidationLine).prefix(8).map { $0 }
  }

  var start = firstErrorIndex
  while start > 0 {
    let candidate = lines[start - 1].trimmingCharacters(in: .whitespacesAndNewlines)
    if candidate.isEmpty {
      break
    }
    if candidate.localizedCaseInsensitiveContains("note:") || candidate.localizedCaseInsensitiveContains("warning:") {
      start -= 1
      continue
    }
    break
  }

  var collected: [String] = []
  var index = start
  while index < lines.count {
    let line = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
    if line.isEmpty {
      if !collected.isEmpty { break }
      index += 1
      continue
    }
    if line.localizedCaseInsensitiveContains("error:")
      || line.localizedCaseInsensitiveContains("note:")
      || line.localizedCaseInsensitiveContains("warning:")
    {
      collected.append(line)
      index += 1
      continue
    }
    if !collected.isEmpty { break }
    index += 1
  }

  return Array(collected.prefix(8))
}

func recordStep(
  _ steps: inout [ValidationStepRecord],
  summary: String,
  status: ValidationStepStatus,
  warningsPresent: Bool = false,
  logPath: String? = nil
) {
  let record = ValidationStepRecord(
    summary: summary,
    status: status,
    warningsPresent: warningsPresent,
    logPath: logPath
  )
  steps.append(record)

  var line = "\(status.rawValue) \(summary)"
  if warningsPresent {
    line += " [warnings]"
  }
  if status == .fail || status == .skip, let logPath {
    line += " (\(logPath))"
  }
  print(line)
}

func printValidationSummary(_ steps: [ValidationStepRecord]) {
  guard !steps.isEmpty else { return }
  print("== Summary")
  for step in steps {
    var line = "\(step.status.rawValue) \(step.summary)"
    if step.warningsPresent {
      line += " [warnings]"
    }
    if step.status == .fail, let logPath = step.logPath {
      line += " -> \(logPath)"
    }
    print(line)
  }
}

func runLoggedValidationCommand(
  _ executable: String,
  _ arguments: [String],
  cwd: String,
  environment: [String: String],
  logPath: String,
  outputMode: ValidateOutputMode
) throws -> ValidationCommandResult {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: executable)
  process.arguments = arguments
  process.currentDirectoryURL = URL(fileURLWithPath: cwd)

  var mergedEnv = ProcessInfo.processInfo.environment
  for (k, v) in environment { mergedEnv[k] = v }
  process.environment = mergedEnv

  let outputPipe = Pipe()
  process.standardOutput = outputPipe
  process.standardError = outputPipe

  try ensureDirectory(URL(fileURLWithPath: logPath).deletingLastPathComponent().path)
  FileManager.default.createFile(atPath: logPath, contents: nil)
  let logHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: logPath))
  defer { try? logHandle.close() }

  let readHandle = outputPipe.fileHandleForReading
  let group = DispatchGroup()
  group.enter()

  let state = ValidationStreamState()

  readHandle.readabilityHandler = { handle in
    let data = handle.availableData
    if data.isEmpty {
      if state.markEOF() {
        group.leave()
      }
      return
    }

    state.append(data, outputMode: outputMode)
    try? logHandle.write(contentsOf: data)

    guard outputMode != .quiet else { return }
    guard let chunk = String(data: data, encoding: .utf8), !chunk.isEmpty else { return }

    if outputMode == .raw {
      print(chunk, terminator: "")
      fflush(stdout)
      return
    }

    for line in state.drainFilteredLines() {
      print(line)
    }
  }

  try process.run()
  process.waitUntilExit()
  readHandle.readabilityHandler = nil
  group.wait()

  let output = state.outputString()
  if outputMode == .filtered, let filtered = state.flushTrailingFilteredLine() {
    print(filtered)
  }

  return ValidationCommandResult(
    status: process.terminationStatus,
    output: output,
    warningsPresent: containsValidationWarnings(output)
  )
}

func runValidationStep(
  title: String,
  summary: String,
  executable: String,
  arguments: [String],
  cwd: String,
  environment: [String: String],
  logPath: String,
  outputMode: ValidateOutputMode,
  steps: inout [ValidationStepRecord]
) throws {
  stepBanner(title)
  printCommandIdentity(executable, arguments)

  let result = try runLoggedValidationCommand(
    executable,
    arguments,
    cwd: cwd,
    environment: environment,
    logPath: logPath,
    outputMode: outputMode
  )

  guard result.status == 0 else {
    if outputMode != .raw {
      for line in extractedFailureDiagnostics(result.output) {
        print(line)
      }
    }
    print("log: \(logPath)")
    recordStep(&steps, summary: summary, status: .fail, warningsPresent: result.warningsPresent, logPath: logPath)
    throw CLIError(message: "Command failed with exit code \(result.status): \(commandString(executable, arguments))")
  }

  recordStep(&steps, summary: summary, status: .pass, warningsPresent: result.warningsPresent, logPath: logPath)
  if result.warningsPresent || outputMode == .quiet {
    print("log: \(logPath)")
  }
}

func changedSwiftFiles(repoPath: String, envVars: [String: String]) throws -> [String] {
  let commands: [[String]] = [
    ["git", "diff", "--name-only", "--", "*.swift"],
    ["git", "diff", "--cached", "--name-only", "--", "*.swift"],
    ["git", "ls-files", "--others", "--exclude-standard", "--", "*.swift"],
  ]

  var seen = Set<String>()
  var ordered: [String] = []

  for command in commands {
    let result = try capture("/usr/bin/env", command, cwd: repoPath, environment: envVars)
    guard result.status == 0 else {
      throw CLIError(message: "Failed to collect changed files: \(command.joined(separator: " "))\n\(result.stderr)")
    }

    for line in result.stdout.split(separator: "\n").map(String.init) {
      let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
      if trimmed.isEmpty || seen.contains(trimmed) { continue }
      seen.insert(trimmed)
      ordered.append(trimmed)
    }
  }

  return ordered
}

func repoName(_ repoPath: String) -> String {
  URL(fileURLWithPath: repoPath).lastPathComponent
}

func listRootFiles(withSuffix suffix: String, in repoPath: String) -> [String] {
  guard let entries = try? FileManager.default.contentsOfDirectory(atPath: repoPath) else { return [] }
  return
    entries
    .filter { $0.hasSuffix(suffix) }
    .sorted()
    .map { URL(fileURLWithPath: repoPath).appendingPathComponent($0).path }
}

func autoDetectWorkspace(repoPath: String) -> String? {
  let preferred = URL(fileURLWithPath: repoPath).appendingPathComponent("\(repoName(repoPath)).xcworkspace").path
  if isValidWorkspace(preferred) { return preferred }
  return listRootFiles(withSuffix: ".xcworkspace", in: repoPath).first(where: { isValidWorkspace($0) })
}

func autoDetectProject(repoPath: String) -> String? {
  let preferred = URL(fileURLWithPath: repoPath).appendingPathComponent("\(repoName(repoPath)).xcodeproj").path
  if isValidProject(preferred) { return preferred }
  return listRootFiles(withSuffix: ".xcodeproj", in: repoPath).first(where: { isValidProject($0) })
}

func isValidWorkspace(_ path: String) -> Bool {
  guard isDirectory(path) else { return false }
  let dataPath = URL(fileURLWithPath: path).appendingPathComponent("contents.xcworkspacedata").path
  return fileExists(dataPath)
}

func isValidProject(_ path: String) -> Bool {
  guard isDirectory(path) else { return false }
  let projectPath = URL(fileURLWithPath: path).appendingPathComponent("project.pbxproj").path
  return fileExists(projectPath)
}

func excludedPath(_ path: String) -> Bool {
  let parts = path.split(separator: "/")
  return parts.contains(".git") || parts.contains(".build") || parts.contains("DerivedData")
}

func shouldIgnoreDiscoveredPackagePath(_ path: String) -> Bool {
  let parts =
    path
    .split(separator: "/")
    .map { $0.lowercased() }

  guard let testsIndex = parts.firstIndex(of: "tests") else { return false }
  return parts[(testsIndex + 1)...].contains("resources")
}

func discoverPackageDirs(repoPath: String, overrides: [String]?, recursive: Bool) -> [String] {
  var ordered: [String] = []
  var seen = Set<String>()

  func addPackageDir(_ candidate: String) {
    let resolved = resolvePath(candidate, repoPath: repoPath)
    let packageFile = URL(fileURLWithPath: resolved).appendingPathComponent("Package.swift").path
    guard fileExists(packageFile) else { return }
    if seen.insert(resolved).inserted {
      ordered.append(resolved)
    }
  }

  if let overrides, !overrides.isEmpty {
    for dir in overrides { addPackageDir(dir) }
    return ordered
  }

  addPackageDir(repoPath)
  addPackageDir("Dependencies/Core")

  guard recursive else { return ordered }

  guard let enumerator = FileManager.default.enumerator(atPath: repoPath) else { return ordered }
  while let item = enumerator.nextObject() as? String {
    if excludedPath(item) {
      enumerator.skipDescendants()
      continue
    }
    if item.hasSuffix("/Package.swift") || item == "Package.swift" {
      let relativePackageDir = (item as NSString).deletingLastPathComponent
      if shouldIgnoreDiscoveredPackagePath(relativePackageDir) {
        continue
      }
      let packageDir = URL(fileURLWithPath: repoPath).appendingPathComponent(relativePackageDir).path
      addPackageDir(packageDir)
    }
  }

  return ordered
}

func toolingPaths(config: Config, repoPath: String) throws -> ToolingPaths {
  let verifyRoot = "\(repoPath)/.build/validation-logs"
  let selectedRoot: String? = config.useCodexCaches ? "/tmp/codex-cache" : nil
  let sharedCacheRoot = selectedRoot.map { "\($0)/cache" }
  let derivedDataPath = selectedRoot.map { "\($0)/xcode/DerivedData" }

  if config.clean {
    try? FileManager.default.removeItem(atPath: verifyRoot)
    if let derivedDataPath {
      try? FileManager.default.removeItem(atPath: derivedDataPath)
    }
  }

  try ensureDirectory(verifyRoot)
  if let sharedCacheRoot {
    try ensureDirectory("\(sharedCacheRoot)/clang-module-cache")
    try ensureDirectory("\(sharedCacheRoot)/swiftpm-module-cache")
    try ensureDirectory("\(sharedCacheRoot)/xdg-cache")
  }
  if let derivedDataPath {
    try ensureDirectory(derivedDataPath)
  }

  let envVars: [String: String]
  if let selectedRoot, let sharedCacheRoot {
    envVars = [
      "CODEX_CACHE_ROOT": selectedRoot,
      "CLANG_MODULE_CACHE_PATH": "\(sharedCacheRoot)/clang-module-cache",
      "SWIFTPM_MODULECACHE_OVERRIDE": "\(sharedCacheRoot)/swiftpm-module-cache",
      "XDG_CACHE_HOME": "\(sharedCacheRoot)/xdg-cache",
    ]
  } else {
    envVars = [:]
  }

  return ToolingPaths(
    cacheRoot: selectedRoot,
    verifyRoot: verifyRoot,
    derivedDataPath: derivedDataPath,
    env: envVars
  )
}

func parseArgs(_ args: [String]) throws -> Config {
  var clean = false
  var useCodexCaches = false
  var target: String?
  var workspaceOverride: String?
  var projectOverride: String?
  var schemes: [String] = []
  var destinations: [String] = []
  var runXcodeTests = false
  var testDestinations: [String] = []
  var packageDirsOverride: [String] = []
  var recursivePackageDiscovery = true
  var swiftPMDisableSandbox = false
  var outputMode: ValidateOutputMode = .filtered

  var i = 0
  while i < args.count {
    switch args[i] {
      case "--target":
        i += 1
        guard i < args.count else { throw CLIError(message: "Missing value for --target") }
        target = args[i]
      case "--clean", "-c":
        clean = true
      case "--use-codex-caches":
        useCodexCaches = true
      case "--workspace":
        i += 1
        guard i < args.count else { throw CLIError(message: "Missing value for --workspace") }
        workspaceOverride = args[i]
      case "--project":
        i += 1
        guard i < args.count else { throw CLIError(message: "Missing value for --project") }
        projectOverride = args[i]
      case "--schemes":
        i += 1
        guard i < args.count else { throw CLIError(message: "Missing value for --schemes") }
        schemes = parseCSV(args[i])
      case "--destinations":
        i += 1
        guard i < args.count else { throw CLIError(message: "Missing value for --destinations") }
        destinations = parseCSV(args[i])
      case "--run-xcode-tests":
        runXcodeTests = true
      case "--test-destinations":
        i += 1
        guard i < args.count else { throw CLIError(message: "Missing value for --test-destinations") }
        testDestinations = parseCSV(args[i])
      case "--package-dirs":
        i += 1
        guard i < args.count else { throw CLIError(message: "Missing value for --package-dirs") }
        packageDirsOverride = parseCSV(args[i])
      case "--no-recursive-packages":
        recursivePackageDiscovery = false
      case "--swiftpm-disable-sandbox":
        swiftPMDisableSandbox = true
      case "--output":
        i += 1
        guard i < args.count else { throw CLIError(message: "Missing value for --output") }
        guard let mode = ValidateOutputMode(rawValue: args[i]) else {
          throw CLIError(message: "Invalid value for --output: \(args[i]). Expected filtered, quiet, or raw.")
        }
        outputMode = mode
      case "--quiet":
        outputMode = .quiet
      case "--raw":
        outputMode = .raw
      case "--help", "-h":
        throw ValidateSignal.helpRequested
      default:
        throw CLIError(message: "Unknown argument: \(args[i])")
    }
    i += 1
  }

  let repoPath = FileManager.default.currentDirectoryPath
  if schemes.isEmpty { schemes = [repoName(repoPath)] }
  if destinations.isEmpty { destinations = ["generic/platform=iOS", "generic/platform=macOS"] }
  if testDestinations.isEmpty { testDestinations = ["platform=macOS"] }

  return Config(
    clean: clean,
    useCodexCaches: useCodexCaches,
    target: target,
    workspaceOverride: workspaceOverride,
    projectOverride: projectOverride,
    schemes: schemes,
    destinations: destinations,
    runXcodeTests: runXcodeTests,
    testDestinations: testDestinations,
    packageDirsOverride: packageDirsOverride.isEmpty ? nil : packageDirsOverride,
    recursivePackageDiscovery: recursivePackageDiscovery,
    swiftPMDisableSandbox: swiftPMDisableSandbox,
    outputMode: outputMode
  )
}

func resolvedWorkspace(config: Config, repoPath: String) -> String? {
  if let override = config.workspaceOverride {
    let resolved = resolvePath(override, repoPath: repoPath)
    return isValidWorkspace(resolved) ? resolved : nil
  }
  return autoDetectWorkspace(repoPath: repoPath)
}

func resolvedProject(config: Config, repoPath: String) -> String? {
  if let override = config.projectOverride {
    let resolved = resolvePath(override, repoPath: repoPath)
    return isValidProject(resolved) ? resolved : nil
  }
  return autoDetectProject(repoPath: repoPath)
}

func runFormatAndLint(repoPath: String, tools: ToolingPaths, outputMode: ValidateOutputMode, steps: inout [ValidationStepRecord]) throws {
  let files = try changedSwiftFiles(repoPath: repoPath, envVars: tools.env)
  if files.isEmpty {
    recordStep(&steps, summary: "format changed Swift files", status: .skip)
    recordStep(&steps, summary: "lint changed Swift files", status: .skip)
    return
  }

  try runValidationStep(
    title: "Format changed Swift files",
    summary: "format changed Swift files",
    executable: "/usr/bin/env",
    arguments: ["swift", "format", "--in-place"] + files,
    cwd: repoPath,
    environment: tools.env,
    logPath: defaultLogPath(tools, "format_changed_swift_files"),
    outputMode: outputMode,
    steps: &steps
  )

  try runValidationStep(
    title: "Lint changed Swift files",
    summary: "lint changed Swift files",
    executable: "/usr/bin/env",
    arguments: ["swift", "format", "lint"] + files,
    cwd: repoPath,
    environment: tools.env,
    logPath: defaultLogPath(tools, "lint_changed_swift_files"),
    outputMode: outputMode,
    steps: &steps
  )
}

func runXcodeBroadValidation(
  config: Config,
  repoPath: String,
  tools: ToolingPaths,
  workspace: String,
  steps: inout [ValidationStepRecord]
) throws {
  let actions = config.clean ? ["clean", "build"] : ["build"]

  for scheme in config.schemes {
    for destination in config.destinations {
      let log = "\(tools.verifyRoot)/comprehensive_\(sanitize(scheme))_\(sanitize(destination))_build.log"
      var args = [
        "xcodebuild",
        "-workspace", workspace,
        "-scheme", scheme,
        "-destination", destination,
      ]
      if let derivedDataPath = tools.derivedDataPath {
        args += ["-derivedDataPath", derivedDataPath]
      }
      if config.outputMode != .raw {
        args.append("-quiet")
      }
      args += ["CODE_SIGNING_ALLOWED=NO"] + actions

      try runValidationStep(
        title: "Build workspace scheme \(scheme) for \(destination)",
        summary: "build \(scheme) (\(destination))",
        executable: "/usr/bin/env",
        arguments: args,
        cwd: repoPath,
        environment: tools.env,
        logPath: log,
        outputMode: config.outputMode,
        steps: &steps
      )
    }
  }

  if config.runXcodeTests {
    for scheme in config.schemes {
      for destination in config.testDestinations {
        let log = "\(tools.verifyRoot)/comprehensive_\(sanitize(scheme))_\(sanitize(destination))_test.log"
        var args = [
          "xcodebuild",
          "-workspace", workspace,
          "-scheme", scheme,
          "-destination", destination,
        ]
        if let derivedDataPath = tools.derivedDataPath {
          args += ["-derivedDataPath", derivedDataPath]
        }
        if config.outputMode != .raw {
          args.append("-quiet")
        }
        args += ["CODE_SIGNING_ALLOWED=NO", "test"]

        try runValidationStep(
          title: "Test workspace scheme \(scheme) for \(destination)",
          summary: "test \(scheme) (\(destination))",
          executable: "/usr/bin/env",
          arguments: args,
          cwd: repoPath,
          environment: tools.env,
          logPath: log,
          outputMode: config.outputMode,
          steps: &steps
        )
      }
    }
  }
}

func parsePackageDescription(packageDir: String, repoPath: String, tools: ToolingPaths) throws -> PackageDescription? {
  var args = ["swift", "package", "--package-path", packageDir]
  if let cacheRoot = tools.cacheRoot {
    let scratchPath = "\(cacheRoot)/swiftpm/\(sanitize(packageDir))"
    try ensureDirectory(scratchPath)
    args += ["--scratch-path", scratchPath]
  }
  args += ["describe", "--type", "json"]

  let result = try capture(
    "/usr/bin/env",
    args,
    cwd: repoPath,
    environment: tools.env
  )

  guard result.status == 0 else {
    let suggestion =
      result.stderr.contains("sandbox_apply: Operation not permitted")
      ? "\nRetry with --swiftpm-disable-sandbox if this environment blocks SwiftPM's internal sandbox."
      : ""
    throw CLIError(message: "Failed to describe Swift package at \(packageDir):\n\(result.stderr)\(suggestion)")
  }
  guard let data = result.stdout.data(using: .utf8) else { return nil }
  return try JSONDecoder().decode(PackageDescription.self, from: data)
}

func isUsableWorkspace(_ workspace: String, repoPath: String, envVars: [String: String]) -> Bool {
  guard isValidWorkspace(workspace) else { return false }
  guard
    let result = try? capture(
      "/usr/bin/env",
      ["xcodebuild", "-list", "-workspace", workspace],
      cwd: repoPath,
      environment: envVars
    )
  else { return false }
  return result.status == 0
}

func isUsableProject(_ project: String, repoPath: String, envVars: [String: String]) -> Bool {
  guard isValidProject(project) else { return false }
  guard
    let result = try? capture(
      "/usr/bin/env",
      ["xcodebuild", "-list", "-project", project],
      cwd: repoPath,
      environment: envVars
    )
  else { return false }
  return result.status == 0
}

func runSwiftPMBroadValidation(
  packages: [String],
  repoPath: String,
  tools: ToolingPaths,
  disableSandbox: Bool,
  outputMode: ValidateOutputMode,
  steps: inout [ValidationStepRecord]
) throws {
  guard !packages.isEmpty else {
    throw CLIError(message: "No Swift package found for broad validation.")
  }

  for packageDir in packages {
    let package: PackageDescription
    do {
      guard let parsed = try parsePackageDescription(packageDir: packageDir, repoPath: repoPath, tools: tools) else {
        throw CLIError(message: "Failed to decode Swift package description at \(packageDir).")
      }
      package = parsed
    } catch {
      throw CLIError(message: "Could not inspect Swift package at \(packageDir) before validation.\n\(error)")
    }

    var buildArgs = ["swift", "build", "--package-path", packageDir]
    var testArgs = ["swift", "test", "--package-path", packageDir]
    if let cacheRoot = tools.cacheRoot {
      let scratchPath = "\(cacheRoot)/swiftpm/\(sanitize(packageDir))"
      try ensureDirectory(scratchPath)
      buildArgs += ["--scratch-path", scratchPath]
      testArgs += ["--scratch-path", scratchPath]
    }
    if disableSandbox {
      buildArgs.append("--disable-sandbox")
      testArgs.append("--disable-sandbox")
    }

    try runValidationStep(
      title: "Build Swift package \(packageDir)",
      summary: "swift build \(packageDir)",
      executable: "/usr/bin/env",
      arguments: buildArgs,
      cwd: repoPath,
      environment: tools.env,
      logPath: defaultLogPath(tools, "swift_build_\(packageDir)"),
      outputMode: outputMode,
      steps: &steps
    )

    guard packageHasTestTargets(package) else {
      recordStep(&steps, summary: "swift test \(packageDir) (no test targets)", status: .skip)
      continue
    }

    try runValidationStep(
      title: "Test Swift package \(packageDir)",
      summary: "swift test \(packageDir)",
      executable: "/usr/bin/env",
      arguments: testArgs,
      cwd: repoPath,
      environment: tools.env,
      logPath: defaultLogPath(tools, "swift_test_\(packageDir)"),
      outputMode: outputMode,
      steps: &steps
    )
  }
}

func runTargetedValidation(
  target: String,
  config: Config,
  repoPath: String,
  tools: ToolingPaths,
  packages: [String],
  workspace: String?,
  project: String?,
  steps: inout [ValidationStepRecord]
) throws {
  var packageInspectionErrors: [String] = []

  for packageDir in packages {
    let package: PackageDescription
    do {
      guard let parsed = try parsePackageDescription(packageDir: packageDir, repoPath: repoPath, tools: tools) else { continue }
      package = parsed
    } catch {
      packageInspectionErrors.append("\(error)")
      continue
    }
    guard package.targets.contains(where: { $0.name == target }) else { continue }

    var buildArgs = ["swift", "build", "--package-path", packageDir, "--target", target]
    var testArgs: [String]?
    if let cacheRoot = tools.cacheRoot {
      let scratchPath = "\(cacheRoot)/swiftpm/\(sanitize(packageDir))"
      try ensureDirectory(scratchPath)
      buildArgs += ["--scratch-path", scratchPath]
      testArgs = ["--scratch-path", scratchPath]
    }
    if config.swiftPMDisableSandbox {
      buildArgs.append("--disable-sandbox")
    }

    try runValidationStep(
      title: "Build Swift target \(target)",
      summary: "swift build \(target)",
      executable: "/usr/bin/env",
      arguments: buildArgs,
      cwd: repoPath,
      environment: tools.env,
      logPath: defaultLogPath(tools, "swift_build_target_\(target)_\(packageDir)"),
      outputMode: config.outputMode,
      steps: &steps
    )

    var candidateTests = [target]
    if !target.hasSuffix("Tests") {
      candidateTests.append("\(target)Tests")
    }

    if let testTarget = candidateTests.first(where: { candidate in
      package.targets.contains(where: { $0.name == candidate && $0.type == "test" })
    }) {
      var swiftTestArgs = ["swift", "test", "--package-path", packageDir, "--filter", testTarget]
      if let extraArgs = testArgs {
        swiftTestArgs += extraArgs
      }
      if config.swiftPMDisableSandbox {
        swiftTestArgs.append("--disable-sandbox")
      }
      try runValidationStep(
        title: "Test Swift target \(testTarget)",
        summary: "swift test \(testTarget)",
        executable: "/usr/bin/env",
        arguments: swiftTestArgs,
        cwd: repoPath,
        environment: tools.env,
        logPath: defaultLogPath(tools, "swift_test_target_\(testTarget)_\(packageDir)"),
        outputMode: config.outputMode,
        steps: &steps
      )
    } else {
      recordStep(&steps, summary: "swift test \(target) (no matching test target)", status: .skip)
    }

    return
  }

  if !packageInspectionErrors.isEmpty && workspace == nil && project == nil {
    throw CLIError(
      message: """
        Could not inspect SwiftPM packages while resolving target '\(target)'.
        \(packageInspectionErrors.joined(separator: "\n\n"))
        Provide --package-dirs to narrow package discovery, or ensure SwiftPM commands can run in this environment.
        """
    )
  }

  if let workspace {
    if !packageInspectionErrors.isEmpty {
      print("SwiftPM target inspection failed; continuing with Xcode workspace fallback.")
    }
    var args = [
      "xcodebuild",
      "-workspace", workspace,
      "-scheme", target,
      "-destination", "generic/platform=macOS",
    ]
    if let derivedDataPath = tools.derivedDataPath {
      args += ["-derivedDataPath", derivedDataPath]
    }
    if config.outputMode != .raw {
      args.append("-quiet")
    }
    args += ["CODE_SIGNING_ALLOWED=NO", "build"]
    try runValidationStep(
      title: "Build workspace scheme \(target) for generic/platform=macOS",
      summary: "build \(target) (generic/platform=macOS)",
      executable: "/usr/bin/env",
      arguments: args,
      cwd: repoPath,
      environment: tools.env,
      logPath: defaultLogPath(tools, "workspace_target_build_\(target)"),
      outputMode: config.outputMode,
      steps: &steps
    )
    return
  }

  if let project {
    if !packageInspectionErrors.isEmpty {
      print("SwiftPM target inspection failed; continuing with Xcode project fallback.")
    }
    var args = [
      "xcodebuild",
      "-project", project,
      "-scheme", target,
      "-destination", "generic/platform=macOS",
    ]
    if let derivedDataPath = tools.derivedDataPath {
      args += ["-derivedDataPath", derivedDataPath]
    }
    if config.outputMode != .raw {
      args.append("-quiet")
    }
    args += ["CODE_SIGNING_ALLOWED=NO", "build"]
    try runValidationStep(
      title: "Build project scheme \(target) for generic/platform=macOS",
      summary: "build \(target) (generic/platform=macOS)",
      executable: "/usr/bin/env",
      arguments: args,
      cwd: repoPath,
      environment: tools.env,
      logPath: defaultLogPath(tools, "project_target_build_\(target)"),
      outputMode: config.outputMode,
      steps: &steps
    )
    return
  }

  throw CLIError(message: "Target '\(target)' was not found in discovered Swift packages, and no Xcode workspace/project is available for scheme fallback. Provide --package-dirs, --workspace, or --project.")
}

func runValidationFlow(_ arguments: [String]) throws {
  let config = try parseArgs(arguments)
  let repoPath = FileManager.default.currentDirectoryPath
  var steps: [ValidationStepRecord] = []

  guard fileExists("\(repoPath)/.git") else {
    throw CLIError(message: "Current working directory is not a git repo root: \(repoPath)")
  }

  do {
    let tools = try toolingPaths(config: config, repoPath: repoPath)
    var workspace = resolvedWorkspace(config: config, repoPath: repoPath)
    var project = resolvedProject(config: config, repoPath: repoPath)
    let packages = discoverPackageDirs(repoPath: repoPath, overrides: config.packageDirsOverride, recursive: config.recursivePackageDiscovery)

    if let ws = workspace, !isUsableWorkspace(ws, repoPath: repoPath, envVars: tools.env) {
      print("Workspace exists but is not usable by xcodebuild: \(ws). Falling back to project/SwiftPM.")
      workspace = nil
    }

    if let proj = project, !isUsableProject(proj, repoPath: repoPath, envVars: tools.env) {
      print("Project exists but is not usable by xcodebuild: \(proj). Falling back to SwiftPM when possible.")
      project = nil
    }

    if let target = config.target {
      try runTargetedValidation(
        target: target,
        config: config,
        repoPath: repoPath,
        tools: tools,
        packages: packages,
        workspace: workspace,
        project: project,
        steps: &steps
      )
      printValidationSummary(steps)
      return
    }

    try runFormatAndLint(repoPath: repoPath, tools: tools, outputMode: config.outputMode, steps: &steps)

    if let workspace {
      try runXcodeBroadValidation(config: config, repoPath: repoPath, tools: tools, workspace: workspace, steps: &steps)
      printValidationSummary(steps)
      return
    }

    if !packages.isEmpty {
      print("No workspace detected. Running SwiftPM broad validation across discovered packages.")
      try runSwiftPMBroadValidation(
        packages: packages,
        repoPath: repoPath,
        tools: tools,
        disableSandbox: config.swiftPMDisableSandbox,
        outputMode: config.outputMode,
        steps: &steps
      )
      printValidationSummary(steps)
      return
    }

    if let project {
      for scheme in config.schemes {
        for destination in config.destinations {
          var args = [
            "xcodebuild",
            "-project", project,
            "-scheme", scheme,
            "-destination", destination,
          ]
          if let derivedDataPath = tools.derivedDataPath {
            args += ["-derivedDataPath", derivedDataPath]
          }
          if config.outputMode != .raw {
            args.append("-quiet")
          }
          args += ["CODE_SIGNING_ALLOWED=NO", "build"]
          try runValidationStep(
            title: "Build project scheme \(scheme) for \(destination)",
            summary: "build \(scheme) (\(destination))",
            executable: "/usr/bin/env",
            arguments: args,
            cwd: repoPath,
            environment: tools.env,
            logPath: "\(tools.verifyRoot)/project_\(sanitize(scheme))_\(sanitize(destination))_build.log",
            outputMode: config.outputMode,
            steps: &steps
          )
        }
      }
      printValidationSummary(steps)
      return
    }

    throw CLIError(message: "No workspace/project or Swift packages detected for broad validation in \(repoPath).")
  } catch {
    printValidationSummary(steps)
    throw error
  }
}
