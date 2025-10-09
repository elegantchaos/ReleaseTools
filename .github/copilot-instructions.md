# ReleaseTools Copilot Instructions

## Project Overview
ReleaseTools (`rt`) is a Swift CLI tool for iOS/macOS release automation - a simpler alternative to Fastlane. 

It handles build numbering, archiving, exporting, App Store uploads, and notarization workflows.

## Architecture

### Command Structure (ArgumentParser)
- **Root**: `RootCommand.swift` registers all subcommands via `CommandConfiguration.subcommands`
- **Commands**: Each in `Sources/ReleaseTools/Commands/*Command.swift` implements `AsyncParsableCommand`
- **Common pattern**: Commands parse their options and then create a `ReleaseEngine` object. They then use this engine, along with local methods, to perform the command's task.
- **Shared options**: Some commands have common options. These are grouped into reusable structs like `CommonOptions`, `SchemeOption`, `PlatformOption` via `@OptionGroup()`

### Core Components
- **ReleaseEngine**: Central state manager for workspace settings, git operations, and file paths. Initialized with command config + options
- **Runners**: Wrappers around shell commands (`GitRunner`, `XCodeBuildRunner`, `XCRunRunner`, `DittoRunner`) - subclass `Runner` from external package
- **WorkspaceSettings**: JSON config (`.rt.json`) with scheme-based, platform-based, and wildcard (`*`) settings hierarchies

### Version Tags
We use git tags to track version and build numbers. 
Tags follow `v<version>-<build>` where version is a semantic version and build is an integer.
An old platform-specific version of the tag format is still supported for compatibility: `v<version>-<build>-<platform>`.
- Examples: `v1.2.3-42`, `v1.2.3-42-iOS`
- `ReleaseEngine+BuildNumber.swift` contains code to parse tags, calculate next build numbers, and find highest tags.
- The archive command requires a tag at HEAD; The `update-build` command looks for the highest tag in the history.

## Build & Test

### Commands
```bash
swift build                             # Build tool
swift run rt <subcommand> [options]     # Run without installing
swift test                              # Run tests (uses Swift Testing framework)
```

### Test Infrastructure
- **TestRepo class**: Creates isolated git repos in temp directories for each test
- Each test repo has dedicated `GitRunner` and `Runner` instances pointing to `.build/debug/rt`
- Tests use `@Test` attribute (Swift Testing) not XCTest
- Pattern: `@Test func testName() async throws { let repo = try await TestRepo(); ... }`
- Tests should be fully isolated and not depend on external state.
- Running tests in parallel should be fine.

### Validating Your Code Changes
- When validating your code changes, prefer adding or updating tests to cover the new or changed functionality.
- If you need to run commands on the local machine to validate your changes:
  - Create temporary content in a directory called AgentTests/ at the root of the workspace
  - This directory should be ignored by git via .gitignore
  - It is ok to run commands manually in this directory to validate your changes, but do not commit any files here.
  - Make sub-directories as needed to organize different test scenarios.
  - It is ok to leave temporary files here, but try to keep it tidy.
  - Periodically you can ask to clean up this directory if it gets too cluttered.

## Key Workflows

### Creating Version Tags
```bash
rt tag                                   # Auto-increment from highest tag
rt tag --explicit-version 1.2.3          # Create v1.2.3-<next-build>
rt tag --explicit-build 42               # Create v<version>-42
```

### App Store Submission
```bash
rt submit                # Full pipeline: archive -> export -> upload
rt archive              # Just archive (requires version tag at HEAD)
rt export               # Export from archive
rt upload               # Upload to App Store Connect
```

### Build Number Injection
- **At archive time**: Parses tag at HEAD, generates `VersionInfo.h`, passes to `xcodebuild` via `-DINFOPLIST_PREFIX_HEADER`
- **During builds**: `rt update-build` generates header/xcconfig/plist with speculative next build number

## Project Conventions

### File Organization
- Commands in `Commands/` subfolder, one file per command
- Runners in `Runners/` subfolder, extend base `Runner` class
- Extensions on structs for logical grouping (e.g., `OptionParser+BuildNumber.swift`)
- Plugin in separate `Plugins/` directory for SPM plugin capability

### Error Handling
- Custom error enums per command (e.g., `TagError`, `ArchiveError`) conform to `Runner.Error`
- Implement `description(for session:)` to extract stderr from failed commands
- Use `throwIfFailed(_:)` on `Runner.Session` to throw typed errors

### Async Patterns
- Swift code is fully async/await where appropriate.
- All commands are `async throws` - use `AsyncParsableCommand`
- Runner sessions use `waitUntilExit()` for status, async sequences for output streams
- When we need to analyse the output of an external process line-by-line, we use the pattern: `for await line in await result.stdout.lines { ... }`
- For short outputs, we can also use `let output = try await result.stdout.string` to get the full output as a string.

### Settings & Defaults
- Settings merge: `*` → scheme → platform → `scheme.platform` (most specific wins)
- Workspace/scheme inferred from folder name if not specified
- `.rt.json` format: `{"defaultScheme": "...", "settings": {"*": {...}, "scheme": {...}}}`

### Coding Conventions
- Use standard Swift naming conventions
- Error cases: descriptive names like `noVersionTagAtHEAD`, `archiveFailed`
- Prefer methods on structs over free functions. 
- Prefer private methods over public where possible.
- When adding new code, generate comments for public methods, types, and properties using `///` syntax
- When adding or changing code, also update or add relevant tests in `Tests/ReleaseToolsTests/`
- When adding or changing code, also update this file to reflect the changes.
- When adding or changing code, also update the README.md file to reflect the changes.
- Do not add // MARK comments to separate sections of code
  - use extensions where appropriate, to group related functionality
  - for tests, use suites and sub-suites instead of // MARK comments

## Dependencies
- **ArgumentParser**: Command-line parsing
- **Runner**: External package for subprocess execution with async streams
- **Logger**: Logging infrastructure (from elegantchaos)
- **Versionator**: Build-time version injection plugin
