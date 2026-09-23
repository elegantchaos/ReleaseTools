# Archive Metadata Diagnostics

`rt submit` and `rt upload` now validate archive metadata before dereferencing it. Missing required archive keys are reported together, including `CFBundleShortVersionString`.

The release engine no longer stores mutable archive state. Commands load a validated archive from the configured archive path when they need it.

The launch configurations now use `releaseTools.targetProject` in `.vscode/settings.json` to select their sibling project.

Error types now live in extensions after the primary definition of their owner. Command errors use `Command.Error: LocalizedError`, and engine-owned failures use `ReleaseEngine.Error`, including subprocess failures: Runner 2.2.0 appends stderr to any error passed to `throwIfFailed`, so no `Runner.Error` conformances remain. It also makes `Session.waitUntilExit()` safe to call repeatedly and reports the real exit state in debug wrapping.

Validation support models have one type per source file outside `Commands/`.

The source root now contains only the release engine and root command. Supporting types are grouped by configuration, options, models, utilities, runners, and validation.
