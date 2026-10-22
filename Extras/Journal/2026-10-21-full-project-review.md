# Full Review: ReleaseTools 5.0.2

Date: 2026-10-21. Reviewed release: `v5.0.2`, commit `950a221861d7ab3bd26a1fa9342e52decf1d9f1a`.

Mode: full review of the entire codebase. Source coverage is complete for this package: all 39 CLI source files, the command-plugin source, all 11 test files, and the package manifest. Supporting documentation, decisions, workflow, editor configuration, shared Xcode schemes, lockfiles, and development script were also inspected. Dependencies are included for boundary checks, not full dependency audits; the ignored `Packages/runner` symlink points to a separately maintained repository and is not a local package dependency in this manifest. No earlier complete full review was found in the journal.

## Summary

ReleaseTools is a compact release automation CLI with useful separation between commands, configuration, archive metadata, and subprocess wrappers. The review found concrete release-safety defects: legacy configuration can be deleted without migration, website publishing includes unrelated changes, and command tests can execute stale binaries. The direct-distribution and plugin paths have additional failures that are not covered by the passing test suite. Production code was not changed during this review.

## Map

| Package / target | Size | Responsibility and interface |
| --- | ---: | --- |
| Root package, `ReleaseTools` | 39 files, 3,266 lines | `rt` executable, 12 subcommands; release engine, configuration, artifact metadata, Git/Xcode runners. No public library product. |
| `ReleaseToolsPlugin` | 1 file, 78 lines | SwiftPM `rt` command plugin and Xcode command-plugin entry point; invokes the executable as a tool. |
| `ReleaseToolsTests` | 11 files, 1,863 lines | Swift Testing suites using direct `@testable` calls and subprocess integration tests through `TestRepo`. |

The actual graph is root command → commands → release engine / configuration / archive models / runner wrappers → external libraries and platform tools. The plugin depends on the executable as a tool; tests depend on its module and also locate a separately built executable. `VersionatorPlugin` generates executable version metadata; ActionBuilder is a separate development workflow dependency. SwiftPM describes the plugin source root as `Plugins`, correctly finding the differently named `ReleaseToolPlugin` subdirectory.

Repeated concepts include source/build/version information in `BuildInfo` and `XcodeArchive`, authentication in option groups/configuration/engine fields, and three subprocess handling implementations: Runner, the asynchronous plugin wrapper, and the synchronous Xcode plugin wrapper. macOS versus iOS/tvOS/watchOS changes archive destinations, output directories, package suffixes, and tag names; notarization, Sparkle, FoundationModels, and Xcode plugin integration are platform-specific.

## Codebase Findings

### Seams

**F1 — Blocking / P1: migration deletes legacy configuration when any canonical configuration exists.**

Evidence: `Sources/ReleaseTools/Configuration/RTLegacyConfigMigrator.swift:45-64`. Existing canonical JSON prevents migration, but the later existence check still deletes `.rt.json` or `.rt.local.json`. The same condition makes a retry after partial migration unsafe. Reproduced separately for project and local configuration: an existing empty canonical `config.json` plus legacy settings, followed by `rt tag --explicit-version 1.0.0 --explicit-build 1`, returned success, deleted the legacy file, and left the canonical file as `{}`. The settings were lost.

Recommended action: preserve the source when destinations already exist, detect conflicts, and remove/retire the legacy file only after the complete migration has been verified. Add coexistence and interrupted-migration coverage for both scopes.

**F2 — Blocking / P1: website publishing commits and pushes unrelated tracked changes.**

Evidence: `Sources/ReleaseTools/Commands/PublishCommand.swift:37-45`. A path-specific `git add` is followed by `git commit -a`, which includes every modified/deleted tracked file in the website repository. Existing unrelated staged changes would also be included by an unrestricted commit. Reproduced using a local bare remote: the resulting release commit contained both `updates/app.zip` and an unrelated edit to `seed.txt`.

Recommended action: commit only the intended release paths and preserve unrelated working-tree/index state; reject ambiguous staging rather than publishing it implicitly. Cover unrelated staged and unstaged files.

**F3 — Should fix / P1: the plugin reports subprocess failures as success.**

Evidence: `Plugins/ReleaseToolPlugin/ReleaseToolPlugin.swift:22-26,63-67`. Both wrappers return stdout without checking `terminationStatus` or `terminationReason`. A harness extracted from the actual asynchronous wrapper returned successfully, with outer exit status 0, when the child exited with status 7. This can turn failed archiving/uploading into a successful plugin action.

Recommended action: propagate failed exit/signal status, preserving stderr and command context, in both entry points. Add plugin failure-path coverage.

**F4 — Should fix / P1: both plugin wrappers can deadlock on normal verbose output.**

Evidence: `Plugins/ReleaseToolPlugin/ReleaseToolPlugin.swift:21-23,61-66`. Stdout is drained only after the child terminates. Once the pipe fills, the child cannot terminate and the parent never starts reading. The extracted asynchronous wrapper stalled with a child writing 1 MiB; the harness was terminated after a bounded timeout. The synchronous wrapper has the same ordering.

Recommended action: drain stdout while the child runs, then await completion. Share the execution policy between entry points and test output larger than pipe capacity.

**F5 — Should fix / P1: command integration tests reuse an executable from an earlier source revision.**

Evidence: `Tests/ReleaseToolsTests/TestRepo.swift:47-59`. `--show-bin-path` locates an artifact but does not build it, and the real build runs only when the executable does not exist. Reproduced in this checkout: the current debug binary printed the new readable tag error, while `.build/test-scratch/release/rt` still printed the old `tagAlreadyExists(...BuildInfo...)` error. The existing command assertion accepts that old error. Direct unit tests compile current source, but `runRT`/`checkedRT` integration tests need not exercise it.

Recommended action: build the intended executable once per test invocation, await and check that build, then pass its path to fixtures. Do not use file existence as a freshness test. Ensure parallel fixtures do not independently race to build the same artifact.

**F6 — Should fix / P1: release completion tags identify current HEAD rather than the archived source.**

Evidence: `Sources/ReleaseTools/Commands/UploadCommand.swift:79-82`, `Sources/ReleaseTools/Commands/WaitForNotarizationCommand.swift:59-63`, and `Sources/ReleaseTools/Models/XcodeArchive.swift`. Neither tagging command specifies a source commit; `wait` additionally uses `-f`. The archive model does not carry provenance for this check. Reproduced with a synthetic old archive, a canonical source tag on commit A, a later HEAD B, and an upload stub returning acceptance: the new platform tag pointed to B, not A. No Apple service was contacted. A successful `wait` can also move an existing tag because it forces the update.

Recommended action: retain or validate the archive's source identity, tag that exact commit, and refuse conflicting existing tags instead of moving them. Test restarting a granular release after HEAD changes.

Checked:

- Compared `RootCommand`, `Package.swift`, the plugin, every command, and the engine's call sites. `swift package describe --type json` confirmed three targets and the actual dependency graph.
- Read configuration paths, reader, document/settings types, migrator, and `ConfigTests`; checked coexistence, specificity, default-scheme resolution, and credential flow. The Swift Configuration dependency documents first-provider precedence, matching `candidateURLs` and the passing precedence test.
- Read Runner's resolved `Session`, `RunState`, `ExitStateCache`, and executable selection to verify caller assumptions. `rg -n '\.state|waitUntilExit|throwIfFailed' Sources Plugins Tests` found direct state consumption in Appcast and the unused scheme-listing helper.
- Compared generation/archive/upload/wait representations and inspected all tag-writing call sites with `rg -n 'versionTag|"tag"|BuildInfo|Commit' Sources Tests`.
- Reproduced F1, F2, F5, and F6 against actual CLI binaries in disposable repositories; reproduced F3/F4 with the extracted wrapper. Fixtures used synthetic data and local remotes only.

### Across the Whole

**F7 — Should fix / P1: the notarization workflow calls a service interface Apple retired.**

Evidence: `Sources/ReleaseTools/Commands/NotarizeCommand.swift:42-50` uses `altool --notarize-app`; `WaitForNotarizationCommand.swift:97-105` uses `altool --notarization-info`. Apple no longer accepts notarization submissions from altool, effective November 1, 2023. This concerns notarization; it does not invalidate altool's App Store upload use. See [Apple's migration guidance](https://developer.apple.com/documentation/technotes/tn3147-migrating-to-the-latest-notarization-tool).

Recommended action: migrate submission, saved receipt, polling, and log retrieval together to notarytool. Update the documented direct-distribution sequence and replace altool-shaped status fixtures with the supported protocol.

**F8 — Should fix / P1: notarization commands never resolve configured API credentials.**

Evidence: `NotarizeCommand.swift:20-30`, `WaitForNotarizationCommand.swift:24-37`, and `ReleaseEngine.swift:168-184`. The engine loads credential fields only when corresponding option-group arguments are non-nil. Neither notarization command declares/passes those groups, but both send `engine.apiKey` and `engine.apiIssuer`. A stub-tool probe with configured fixture credentials captured empty `--apiIssuer` and `--apiKey` arguments.

Recommended action: resolve configuration independently of option-group presence, and explicitly validate authentication for commands that require it. Provide the intended command-line overrides consistently. Search covered all `getSettings()`, credential assignments, and initializer call sites; upload/submit do supply the groups.

**F9 — Should fix / P1: Appcast success falls through into key generation; an ordinary failure can crash.**

Evidence: `Sources/ReleaseTools/Commands/AppcastCommand.swift:59-92`. A `.succeeded` result skips the failure condition but still enters key generation and throws `generatedKeys`. A probe with a successful generator and harmless key-generation stub confirmed that key generation was attempted and the command failed. On a non-key-related failure, calling `throwIfFailed` after consuming `genResult.state` rereads its one-shot stream; the resolved Runner cache reaches its fatal error when that consumed stream produces no value. The latter is confirmed by source tracing, not an intentional crash run.

Recommended action: obtain the final state once through the cached API, finish on success, and enter key recovery only for a recognized missing-key failure. Add success, missing-key, ordinary failure, and repeated-state-access tests before invoking real keychain tools.

Checked:

- `rg -n 'Process\(|readDataToEndOfFile|waitUntilExit|\.state|Task|Dispatch|nonisolated' Sources Plugins Tests` found the plugin pipe/continuation issues and Appcast state misuse. The command-local engine is not shared between concurrent release tasks; no additional actor-reentrancy defect was found.
- `rg -n 'try\?|removeItem|copyItem|moveItem|commit", "-a|"-f"' Sources Plugins Tests` found ignored filesystem errors in export/stapling/Appcast and the forced completion tag. Error masking in stapling should be addressed with the notarization rewrite.
- Compared all `LocalizedError` implementations and the shared error-ownership decision. Most command errors follow the decision; configuration retains a separate shared error type. A malformed-config CLI probe produced a readable diagnostic, so no diagnostic defect is claimed for that type.
- `rg -n 'semaphore|apiKeyURL|schemes\(|SchemesSpec|isInvalidBundleError' Sources Tests` found unused engine state/accessors, an unused scheme-listing path, and a bundle-error flag used only by tests. These are simplification opportunities, not release blockers.
- Read all six roadmap documents, README, release notes, journal, decisions, agent guidance, and Copilot instructions. Configuration/overlay roadmap items describe work that is already implemented; Copilot error guidance still prescribes the superseded `Runner.Error` pattern. Other documentation drift is listed under Follow-ups.

## Package Findings

### ReleaseTools executable

F1, F2, F6–F9 are the highest-risk CLI findings. Additional defects:

**F10 — Should fix / P2: plist generation writes the wrong type for `CFBundleVersion`.**

Evidence: `Sources/ReleaseTools/ReleaseEngine+Generation.swift:68`. `UInt` is serialized as a plist integer. A CLI probe confirmed an integer output; `GenerationTests.swift:213` explicitly expects that type. [Apple defines this field as a string](https://developer.apple.com/documentation/BundleResources/Information-Property-List/CFBundleVersion). The generated metadata therefore violates the documented bundle format.

Recommended action: serialize the build as a string and update tests to check the consumer's required type, including repeated generation.

**F11 — Should fix / P2: matching source build numbers suppress required destination/header generation.**

Evidence: `ReleaseEngine+Generation.swift:64-78`. The source's build number alone controls the early no-op. Running `update-build --plist Source.plist --plist-dest Info.plist` with source build `1` and computed build `1` returned success while neither `Info.plist` nor `RTInfo.h` existed. Changed commit/version metadata can likewise be left stale. `GenerationTests.swift:229-259` preserves the current behavior instead of checking destination existence.

Recommended action: generate the complete expected output, compare it with the destination, and decide whether to write from that comparison. Ensure the companion header is independently present/current.

**F12 — Should fix / P2: generating a new xcconfig file reports failure because it is untracked.**

Evidence: `ReleaseEngine+Generation.swift:43-50`. After writing, the command unconditionally runs `git update-index --assume-unchanged`. A fresh `update-build --config Fresh.xcconfig` created the file but exited 1 with `Failed to tell git to ignore the config file.` The generation tests catch all errors around this behavior, weakening their ability to identify other failures.

Recommended action: separate successful content generation from an explicit tracked-file ignore policy; handle new/ignored files predictably and test precise expected outcomes. Do not hide unrelated exceptions with blanket catches.

**F13 — Should fix / P2: `tag` can create version tags its own archive path cannot recognize.**

Evidence: `Sources/ReleaseTools/Commands/TagCommand.swift:35-58` accepts any explicit version and accepts build zero via `UInt`. The reader's regex in `ReleaseEngine+BuildNumber.swift:11-16` requires numeric version components. Reproduced: `rt tag --explicit-version banana --explicit-build 0` exited successfully and created `vbanana-0`, which is not a recognized version tag. The build error text calls for a positive integer despite accepting zero.

Recommended action: validate creation and reading against one version-tag contract, rejecting malformed versions and unsupported build values before mutating Git. Decide explicitly whether prerelease versions are supported rather than silently creating unusable tags.

**F15 — Should fix / P2: valid legacy configuration with no selector settings is rejected as mixed-schema.**

Evidence: `Sources/ReleaseTools/Configuration/RTLegacyConfigMigrator.swift:77-87,170-180`. An empty settings dictionary has no nested values, so `schemaForSettings` classifies it as canonical even when `defaultScheme` explicitly identifies the legacy layout. A fixture containing only `{"defaultScheme":"App","settings":{}}` was rejected as mixing old and canonical schemas.

Recommended action: treat an empty settings map as ambiguous/empty, using the other schema markers to classify it; test defaults-only legacy documents and empty maps. This is distinct from F1's destructive coexistence behavior.

Checked: every file in `Sources/ReleaseTools` was read in full, including all command registrations, the deterministic/optional FoundationModels change-log paths, configuration/migration, archive parsing, receipt normalization, generation, options, runners, and utility decoding. Existing archive-required-key aggregation and the recently added upload/tag diagnostics follow their tests. The archive validation decision is preserved; there is no reintroduced cached archive state. See the file inventory below for exact coverage.

### ReleaseToolsPlugin

F3/F4 apply to both SwiftPM and Xcode entry points. No production code change is required to establish the failures in the extracted subprocess wrapper.

Checked: the entire 78-line plugin and its manifest wiring. An actual invocation, `swift package plugin --allow-writing-to-package-directory rt no-such-review-command`, failed before entry-point execution with `Could not find target named 'ReleaseTools-product'`. The toolchain/SwiftPM resolution cause was not diagnosed; this result is not used as proof of F3/F4 and end-to-end plugin execution remains unverified.

### ReleaseToolsTests

F5 undermines subprocess test freshness. Generation tests also encode F10/F11 and use broad catches around F12. Tests cover tags, metadata generation, configuration precedence/migration, archive diagnostics, changes output, and receipt/status interpretation; there are no command-level success/failure tests for Appcast, publish, notarization execution, plugin execution, or archive/export argument construction.

Checked: all 11 test files and `TestRepo`. Temporary directories are isolated by UUID, but TestRepo/config-test fixtures lack cleanup and share one executable build location. Direct receipt tests use synthetic Xcode app metadata and do not depend on a particular installed Xcode. The exact tag-error unit test compiles current source despite the integration-binary issue.

### Workflow, documentation, and development tooling

**F14 — Should fix / P2: the CI fallback installer redirects into a directory that does not exist yet.**

Evidence: `.github/workflows/Tests.yml:22-36`. When xcbeautify is absent, `brew install ... > logs/install-xcbeautify.log` is evaluated before the `mkdir logs` step. Redirection fails before Homebrew runs, so the intended fallback cannot install the tool. Existing successful runners with xcbeautify already present do not exercise this branch.

Recommended action: create the log directory before any redirected command and exercise the missing-tool branch. `actionlint` passes because the workflow is syntactically valid; this is a runtime ordering defect.

Checked: `Package.swift`, both tracked lockfiles, `.github/workflows/Tests.yml`, `.github/copilot-instructions.md`, `.bin/make-test-repo`, `.gitignore`, `.swift-format`, `.swift-version`, VS Code files, all tracked shared Xcode schemes/workspace files, README, release notes, roadmap, decisions, and existing journal. Shared schemes contain obsolete target names and personal working directories; the older secondary lockfile pins versions inconsistent with the active manifest. Treat these as stale development artifacts until their intended ownership is established.

## Follow-ups

1. Fix F5 first so command integration tests exercise the current build. Add deterministic fixture-backed coverage for migration coexistence, scoped publishing, and archive provenance before fixing F1/F2/F6.
2. Repair the direct-distribution path as a coherent unit: supported notarization protocol, explicit credential resolution, current status/log fixtures, correct Appcast control flow, and filesystem failures that retain their cause. Do not silently rotate or regenerate signing keys on success.
3. Use one subprocess result policy across both plugin entry points: drain output during execution, retain stderr, and propagate status. A small shared helper is sufficient; no new package architecture is required by these findings.
4. Remove obsolete engine fields/helpers after verifying callers: `semaphore`, `apiKeyURL`, unused scheme discovery, unused initializer command metadata, and test-only error classification. Keep `BuildInfo` and `XcodeArchive` separate for their distinct responsibilities, but make source provenance explicit between them.
5. Bring guidance and tooling back into agreement: retire completed configuration/overlay roadmap items, update Copilot instructions, replace obsolete `--increment-tag`, `--to`, and `--latest` examples, and correct README statements about already-tagged incremental builds. The CI step labeled release Swift Testing omits `--configuration release` and actually runs that suite in debug. Make its label or configuration accurate.
6. Apply documentation/organization standards consistently in a separate cleanup: several legacy files lack member documentation, `UploadReceipt.swift` contains multiple top-level types, old test files use force casts/negated expectations, and some paths in editor settings/shared schemes are machine-specific. The existing single lint warning is in `XcodeArchiveTests.swift:148`; broader standards are not enforced by current formatter settings.

## Validation and evidence

| Check | Result / limit |
| --- | --- |
| Full `agt validate` on clean PR head `976f509e20e44200bb9ad76485386ee5cf859293` | Passed macOS build and 67 tests in 10 suites. `git diff` confirmed the released merge tree has identical source. Not repeated solely because the merge/tag changed. |
| GitHub CI for PR #17 | Both runs passed before merge. |
| `swift format lint --recursive Sources Plugins Tests` | Passed with the one existing for-each lint warning. No formatting changes applied during review. |
| `actionlint .github/workflows/Tests.yml` | Passed; does not cover F14's runtime branch. |
| `swift package describe --type json` | Confirmed the target map and resolved plugin source location. |
| Disposable CLI probes | Confirmed F1, F2, F5, F6, F8, F9 success fall-through, F10–F13, and F15. Apple/Xcode/keychain operations were stubbed; Git publishing used a local bare remote. |
| Extracted plugin-wrapper harness | Child exit 7 returned success; 1 MiB stdout stalled until the bounded harness timeout. |
| Actual plugin invocation | Blocked by pre-execution SwiftPM tool-resolution error; see plugin findings. |
| `git diff --check` | Passed before writing the report; repeated after report generation. |

## Not Checked

- No source or test file in this package was omitted from the read-through. Dependencies, including other repositories maintained by the same author, were not audited in full. Runner and Swift Configuration were inspected only where caller contracts mattered.
- No real Apple upload/notarization, real key generation/import, or external website publication was performed. Service-side behavior beyond the cited Apple documentation is unverified.
- No signed archive/export was executed for macOS, iOS, tvOS, or watchOS; scheme/platform arguments were inspected statically. This review does not prove signing, SDK, or account compatibility.
- The actual SwiftPM plugin could not reach its entry point on this toolchain. The Xcode plugin entry point was inspected statically; only the extracted async wrapper was executed.
- FoundationModels summary quality, Keychain interaction, cancellation under real tool load, and filesystem failure recovery were not exercised. Appcast's ordinary-error stream-consumption crash is a source-level finding, not a deliberately induced crash.
- The report and journal index are the only intended tracked changes from this review. Findings are recommendations, not implemented fixes or newly recorded decisions.

## Files read in full

The inventory below records production and test coverage; supporting files are named in the checked records above.

### Sources

- `Sources/ReleaseTools/Commands/AppcastCommand.swift`
- `Sources/ReleaseTools/Commands/ArchiveCommand.swift`
- `Sources/ReleaseTools/Commands/ChangesCommand.swift`
- `Sources/ReleaseTools/Commands/CompressCommand.swift`
- `Sources/ReleaseTools/Commands/ExportCommand.swift`
- `Sources/ReleaseTools/Commands/NotarizeCommand.swift`
- `Sources/ReleaseTools/Commands/PublishCommand.swift`
- `Sources/ReleaseTools/Commands/SubmitCommand.swift`
- `Sources/ReleaseTools/Commands/TagCommand.swift`
- `Sources/ReleaseTools/Commands/UpdateBuildCommand.swift`
- `Sources/ReleaseTools/Commands/UploadCommand.swift`
- `Sources/ReleaseTools/Commands/WaitForNotarizationCommand.swift`
- `Sources/ReleaseTools/Configuration/BasicSettings.swift`
- `Sources/ReleaseTools/Configuration/RTConfigDocument.swift`
- `Sources/ReleaseTools/Configuration/RTConfigError.swift`
- `Sources/ReleaseTools/Configuration/RTConfigPaths.swift`
- `Sources/ReleaseTools/Configuration/RTConfigReader.swift`
- `Sources/ReleaseTools/Configuration/RTLegacyConfigMigrator.swift`
- `Sources/ReleaseTools/Models/SchemesSpec.swift`
- `Sources/ReleaseTools/Models/UploadReceipt.swift`
- `Sources/ReleaseTools/Models/WorkspaceSpec.swift`
- `Sources/ReleaseTools/Models/XcodeArchive.swift`
- `Sources/ReleaseTools/Options/ApiIssuerOption.swift`
- `Sources/ReleaseTools/Options/ApiKeyOption.swift`
- `Sources/ReleaseTools/Options/CommonOptions.swift`
- `Sources/ReleaseTools/Options/PlatformOption.swift`
- `Sources/ReleaseTools/Options/SchemeOption.swift`
- `Sources/ReleaseTools/Options/UpdatesOption.swift`
- `Sources/ReleaseTools/Options/WebsiteOption.swift`
- `Sources/ReleaseTools/ReleaseEngine+BuildNumber.swift`
- `Sources/ReleaseTools/ReleaseEngine+Generation.swift`
- `Sources/ReleaseTools/ReleaseEngine.swift`
- `Sources/ReleaseTools/RootCommand.swift`
- `Sources/ReleaseTools/Runners/DittoRunner.swift`
- `Sources/ReleaseTools/Runners/GitRunner.swift`
- `Sources/ReleaseTools/Runners/XCRunRunner.swift`
- `Sources/ReleaseTools/Runners/XCodeBuildRunner.swift`
- `Sources/ReleaseTools/Utilities/Codable+DashCase.swift`
- `Sources/ReleaseTools/Utilities/CommandLine+Name.swift`

### Plugins

- `Plugins/ReleaseToolPlugin/ReleaseToolPlugin.swift`

### Tests

- `Tests/ReleaseToolsTests/ChangesCommandTests.swift`
- `Tests/ReleaseToolsTests/ConfigTests.swift`
- `Tests/ReleaseToolsTests/GenerationTests.swift`
- `Tests/ReleaseToolsTests/ReleaseEngineErrorTests.swift`
- `Tests/ReleaseToolsTests/TagCommandTests.swift`
- `Tests/ReleaseToolsTests/TestRepo.swift`
- `Tests/ReleaseToolsTests/UploadCommandTests.swift`
- `Tests/ReleaseToolsTests/UploadReceiptTests.swift`
- `Tests/ReleaseToolsTests/VersionTagTests.swift`
- `Tests/ReleaseToolsTests/WaitForNotarizationCommandTests.swift`
- `Tests/ReleaseToolsTests/XcodeArchiveTests.swift`
