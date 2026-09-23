# Archive Metadata Diagnostics

`rt submit` and `rt upload` now validate archive metadata before dereferencing it. Missing required archive keys are reported together, including `CFBundleShortVersionString`.

The release engine no longer stores mutable archive state. Commands load a validated archive from the configured archive path when they need it.

The launch configurations now use `releaseTools.targetProject` in `.vscode/settings.json` to select their sibling project.

Error types now live in extensions after the primary definition of their owner. Command workflow errors use `Command.Error: LocalizedError`; subprocess-session errors use `Command.RunnerError: Runner.Error`. Engine-owned failures use `ReleaseEngine.Error` or `ReleaseEngine.RunnerError`.

Validation support models have one type per source file outside `Commands/`.

The source root now contains only the release engine and root command. Supporting types are grouped by configuration, options, models, utilities, runners, and validation.
