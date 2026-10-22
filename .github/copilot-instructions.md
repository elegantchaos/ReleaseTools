# ReleaseTools project guide

Follow `AGENTS.md` and its shared skills for coding, records, Git, and validation.

ReleaseTools provides the `rt` executable for Apple application release automation.
`RootCommand` registers ArgumentParser commands in `Sources/ReleaseTools/Commands/`.
Commands resolve options through `ReleaseEngine`, which owns repository paths,
layered configuration, Git operations, and progress output. Runner subclasses in
`Runners/` execute Git, Xcode, and archive tools.

Configuration uses canonical JSON documents under `.rt/` and the matching global
configuration directory. `RTConfigPaths` defines scope precedence; `RTConfigReader`
uses Swift Configuration providers. See README.md for the schema and file layout.

Version tags use `v<version>-<build>`. Platform-specific tags are also considered
when calculating the next build number. Archiving requires a version tag at HEAD.
`ReleaseEngine+BuildNumber.swift` owns parsing and selection.

Tests use Swift Testing. `TestRepo` creates isolated Git repositories and runs the
executable built alongside the current test bundle. It never reuses a separate
cached build. Domain failures use nested `LocalizedError` enums.

Use `swift build`, `swift run rt <command>`, and `swift test` for focused work.
Run `agt format` and `agt validate` for standard validation. Generate workflows and
README badges with the installed `ActionBuilderTool` from the repository root.
Versionator supplies executable version metadata through its build plugin.
