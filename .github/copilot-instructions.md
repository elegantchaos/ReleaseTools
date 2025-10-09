# ReleaseTools Copilot Instructions

## Project Overview
ReleaseTools (`rt`) is a Swift CLI tool for iOS/macOS release automation - a simpler alternative to Fastlane. It handles build numbering, archiving, exporting, App Store uploads, and notarization workflows.

## Architecture

### Command Structure (ArgumentParser)
- **Root**: `RootCommand.swift` registers all subcommands via `CommandConfiguration.subcommands`
- **Commands**: Each in `Sources/ReleaseTools/Commands/*Command.swift` implements `AsyncParsableCommand`
- **Common pattern**: Commands create an `OptionParser` for common options, parse additional command-specific options, then call local methods to perform tasks
- **Shared options**: `CommonOptions`, `SchemeOption`, `PlatformOption` via `@OptionGroup()`

### Core Components
- **OptionParser**: Central state manager for workspace settings, git operations, and file paths. Initialized with command config + options
- **Runners**: Wrappers around shell commands (`GitRunner`, `XCodeBuildRunner`, `XCRunRunner`, `DittoRunner`) - subclass `Runner` from external package
- **WorkspaceSettings**: JSON config (`.rt.json`) with scheme-based, platform-based, and wildcard (`*`) settings hierarchies
- **Generation**: Static utilities for generating version headers/configs

### Version Tag System
**Critical Pattern**: Tags follow `v<version>-<build>` (platform-agnostic) or `v<version>-<build>-<platform>` (platform-specific)
- Examples: `v1.2.3-42`, `v1.2.3-42-iOS`
- `OptionParser+BuildNumber.swift`: Tag parsing, build number calculation, highest tag detection
- Archive command requires tag at HEAD; `update-build` command looks for the highest tag in the history.

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
- Pattern: `for await line in await result.stdout.lines { ... }`

### Settings & Defaults
- Settings merge: `*` → scheme → platform → `scheme.platform` (most specific wins)
- Workspace/scheme inferred from folder name if not specified
- `.rt.json` format: `{"defaultScheme": "...", "settings": {"*": {...}, "scheme": {...}}}`

### Naming Conventions
- Private helpers start with lowercase: `findHighestTag()`, `getAllTags()`
- Public/internal APIs use camelCase without prefix
- Regex patterns: `platformAgnosticTagPattern`, `platformSpecificTagPattern`
- Error cases: descriptive names like `noVersionTagAtHEAD`, `archiveFailed`
- Prefer methods on structs over free functions. Prefer private methods over public where possible.

## Common Pitfalls

1. **Tag fetching**: Always call `ensureTagsUpToDate(using: git)` before reading tags (handles repos without remotes gracefully)
2. **Async iteration**: Collect tags into array if needed for multiple passes - async sequences can't be replayed
3. **Platform defaults**: Commands support `--platform` but default to `macOS` if not in settings
4. **HEAD tag requirement**: `archive`/`submit` require version tag at HEAD; `update-build` does not

## Dependencies
- **ArgumentParser**: Command-line parsing
- **Runner**: External package for subprocess execution with async streams
- **Logger**: Logging infrastructure (from elegantchaos)
- **Versionator**: Build-time version injection plugin
