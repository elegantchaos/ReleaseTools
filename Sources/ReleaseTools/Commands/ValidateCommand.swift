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

struct ToolingPaths {
  let cacheRoot: String?
  let verifyRoot: String
  let derivedDataPath: String?
  let env: [String: String]
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

  print("+ " + ([executable] + arguments).joined(separator: " "))

  try process.run()
  process.waitUntilExit()

  if process.terminationStatus != 0 {
    throw CLIError(message: "Command failed with exit code \(process.terminationStatus): " + ([executable] + arguments).joined(separator: " "))
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
    swiftPMDisableSandbox: swiftPMDisableSandbox
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

func runFormatAndLint(repoPath: String, tools: ToolingPaths) throws {
  let files = try changedSwiftFiles(repoPath: repoPath, envVars: tools.env)
  if files.isEmpty {
    print("No changed Swift files detected; skipping format/lint.")
    return
  }

  _ = try run("/usr/bin/env", ["swift", "format", "--in-place"] + files, cwd: repoPath, environment: tools.env)
  _ = try run("/usr/bin/env", ["swift", "format", "lint"] + files, cwd: repoPath, environment: tools.env)
}

func runXcodeBroadValidation(config: Config, repoPath: String, tools: ToolingPaths, workspace: String) throws {
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
      args += ["CODE_SIGNING_ALLOWED=NO"] + actions

      _ = try run("/usr/bin/env", args, cwd: repoPath, environment: tools.env)
      try "command output streamed to terminal\n".write(toFile: log, atomically: true, encoding: .utf8)
      print("build log: \(log)")
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
        args += ["CODE_SIGNING_ALLOWED=NO", "test"]

        _ = try run("/usr/bin/env", args, cwd: repoPath, environment: tools.env)
        try "command output streamed to terminal\n".write(toFile: log, atomically: true, encoding: .utf8)
        print("test log: \(log)")
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

func runSwiftPMBroadValidation(packages: [String], repoPath: String, tools: ToolingPaths, disableSandbox: Bool) throws {
  guard !packages.isEmpty else {
    throw CLIError(message: "No Swift package found for broad validation.")
  }

  for packageDir in packages {
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
    _ = try run(
      "/usr/bin/env",
      buildArgs,
      cwd: repoPath,
      environment: tools.env
    )
    _ = try run(
      "/usr/bin/env",
      testArgs,
      cwd: repoPath,
      environment: tools.env
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
  project: String?
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

    _ = try run(
      "/usr/bin/env",
      buildArgs,
      cwd: repoPath,
      environment: tools.env
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
      _ = try run(
        "/usr/bin/env",
        swiftTestArgs,
        cwd: repoPath,
        environment: tools.env
      )
      print("test target: \(testTarget)")
    } else {
      print("No SwiftPM test target matched for \(target); build-only targeted validation completed.")
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
    args += ["CODE_SIGNING_ALLOWED=NO", "build"]
    _ = try run(
      "/usr/bin/env",
      args,
      cwd: repoPath,
      environment: tools.env
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
    args += ["CODE_SIGNING_ALLOWED=NO", "build"]
    _ = try run(
      "/usr/bin/env",
      args,
      cwd: repoPath,
      environment: tools.env
    )
    return
  }

  throw CLIError(message: "Target '\(target)' was not found in discovered Swift packages, and no Xcode workspace/project is available for scheme fallback. Provide --package-dirs, --workspace, or --project.")
}

func runValidationFlow(_ arguments: [String]) throws {
  let config = try parseArgs(arguments)
  let repoPath = FileManager.default.currentDirectoryPath

  guard fileExists("\(repoPath)/.git") else {
    throw CLIError(message: "Current working directory is not a git repo root: \(repoPath)")
  }

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
      project: project
    )
    return
  }

  try runFormatAndLint(repoPath: repoPath, tools: tools)

  if let workspace {
    try runXcodeBroadValidation(config: config, repoPath: repoPath, tools: tools, workspace: workspace)
    return
  }

  if !packages.isEmpty {
    print("No workspace detected. Running SwiftPM broad validation across discovered packages.")
    try runSwiftPMBroadValidation(packages: packages, repoPath: repoPath, tools: tools, disableSandbox: config.swiftPMDisableSandbox)
    return
  }

  if let project {
    // Xcode project-only fallback for broad validation.
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
        args += ["CODE_SIGNING_ALLOWED=NO", "build"]
        _ = try run(
          "/usr/bin/env",
          args,
          cwd: repoPath,
          environment: tools.env
        )
      }
    }
    return
  }

  throw CLIError(message: "No workspace/project or Swift packages detected for broad validation in \(repoPath).")
}
