# Plugin retirement and test executable freshness

The user requested a feature branch, removal of the package command plugin and
legacy configuration support, refreshed ActionBuilder workflows, a complete Swift
formatting/comment/layout pass, and a fix for review finding F5.

Work is on `feature/retire-plugin-and-legacy-config`, based on the released 5.0.2
main branch. The preceding [full review](2026-10-21-full-project-review.md) remains
an unchanged historical record of that release.

## Changes

- Removed the `rt-plugin` product, command-plugin target and source, and the
  ActionBuilderPlugin package dependency. Versionator remains the build-time
  provider of executable version metadata.
- Removed configuration migration, its errors, its path helpers, and empty-schema
  checks. Only canonical project/global JSON configuration is read. Initialization
  leaves `.rt.json`, `.rt.local.json`, and `.gitignore` untouched. Canonical
  configuration precedence and scheme resolution retain integration coverage.
- Moved the JSON fixture encoder into the test target; production configuration
  loading uses Swift Configuration. Configuration load errors now belong to
  `RTConfigReader` and provide `LocalizedError` descriptions.
- Replaced the separate existence-only test executable cache with the executable
  beside the current test bundle. SwiftPM builds that executable dependency with
  the tests. Missing executables fail explicitly instead of falling back to a
  cached build or launching a nested package build.
- Strengthened the duplicate-tag integration test to require the exact readable
  error. Before the fix it failed against the cached executable's old
  `tagAlreadyExists(BuildInfo(...))` error; it passes with the current executable.
- Ran installed ActionBuilderTool 2.2.6 to generate caller/reusable workflows and
  README badges. The generated Swift jobs create logs before installing
  xcbeautify and run Swift Testing explicitly in release configuration.
- Applied Swift headers, member documentation, declaration spacing, stored-member
  ordering, and nested-helper placement throughout the remaining code. Split
  receipt models into individual files and the coding-key utility into its own
  focused files. Removed unused workspace-listing models/method, engine state,
  and initializer argument. Replaced force unwraps/casts and redundant narrative
  comments; narrowed generation tests' catches to the expected wrapped Git-index
  failure rather than swallowing arbitrary failures.
- Updated README, agent/Copilot guidance, ignore rules, and roadmap. Removed
  implemented configuration roadmap documents.

These changes apply the existing [error ownership](../Decisions/2026-09-23-error-type-ownership.md)
and [source organization](../Decisions/2026-09-23-source-tree-organisation.md) decisions.
Other findings in the full review remain follow-up work.

## Validation

- Red regression run: duplicate-tag error and ignored legacy-file tests failed
  before implementation, reproducing stale executable reuse and automatic migration.
- Focused green run: 5 tests passed after implementation.
- `agt format`: 50 Swift files formatted and linted, no findings.
- `agt validate --fast`: package build and all 65 tests in 10 suites passed.
- `swift test -c release --filter 'TagCommandTests|ConfigTests'`: 14 tests passed,
  including executable discovery and exact duplicate-tag output in release mode.
- `actionlint` and `git diff --check`: passed.
- Full `agt validate`: macOS package build and all 65 tests in 10 suites passed.
- Changed-file skill checklist: headers, documentation, declaration layout, type
  ownership, safe unwraps, test assertions, and lint checked across the remaining
  Swift files. No project-code exceptions or outstanding lint findings.

One cleanup validation run initially failed because Runner wraps domain errors;
catch clauses were corrected to inspect `Runner.WrappedError.error`, then the full
fast test suite passed. A sandboxed validation-plan probe could not access Xcode;
the normal approved probe confirmed macOS package build/test coverage.

No App Store submissions, notarization requests, website publications, or remote
GitHub Actions runs were performed. Release compilation emitted one nullability
warning in the pinned third-party swift-subprocess dependency; project Swift lint
is clean.

## Publication validation — 2026-10-22

Before committing and opening the feature PR, reran `agt format` (50 Swift files,
no lint findings), full `agt validate` (macOS build and 65 tests in 10 suites),
`actionlint`, and `git diff --check`. All passed.

## Copyright correction — 2026-10-22

The user clarified that consistent copyright formatting must preserve each file's
original year. Restored years from the pre-cleanup sources, including source
provenance for split/moved files; retained the standardized copyright wording.

## Header provenance correction — 2026-10-22

Audited creation and copyright dates together after the user identified conflicting
years. BasicSettings already existed in WorkspaceSettings (created 12 August 2025,
introduced by commit 97acfee); extraction in March 2026 copied an unrelated 2020
copyright. Its header now retains the originating 2025 date and publication year.
RTConfigDocument was introduced in March 2026 and uses 2026.

Restored originating dates for receipt and coding-key types split into new files,
and corrected newly added headers for Package.swift and ConfigTests using their
initial Git additions. Existing creation dates were preserved elsewhere, and
copyright years now agree with the originating creation years. Checked all 50
Swift headers for consistency; the corrections only affect header comments.
