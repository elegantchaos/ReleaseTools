# Validate command process cleanup

## Goal

Remove the one-off `Foundation.Process` execution layer from `ValidateCommand` by using the shared `Runner` package, and make validation state visible while Swift package manifests are evaluated.

## High-level tasks

1. Replace the local `run`, `capture`, and `runLoggedValidationCommand` process lifecycle code with `Runner`.
2. Add reusable output support to `Runner` where necessary so validation can preserve complete merged logs while still providing filtered, quiet, and raw terminal output modes.
3. Preserve working-directory selection, environment overrides, command display, exit-status handling, warning detection, failure extraction, and PASS/FAIL/SKIP summaries during the migration.
4. Remove unused process helpers and convert the validation call chain to async where required by `Runner`.
5. Set `VALIDATING=1` in the environment of every `swift` process launched by `rt validate`, including package inspection, formatting, builds, and tests, so evaluated `Package.swift` manifests can detect validation.
6. Retain the existing `-DVALIDATING` compiler definition for source-level conditional compilation; the environment variable complements it by being available during manifest evaluation.
7. Add focused tests for Runner-backed capture and output shaping, complete log creation, failure propagation, and the exact environment supplied to Swift commands.

## Notes

- `Runner` already provides process execution, capture and forwarding modes, working-directory control, environment injection, and exit-state handling. Validation should extend that shared abstraction instead of maintaining a parallel implementation.
- `Runner` does not currently expose the exact combination of merged raw logging and filtered live output required by validation. Add this as reusable upstream behavior rather than retaining bespoke process management in `ValidateCommand`.
- Limit `VALIDATING=1` to child Swift invocations made by the validate command; unrelated ReleaseTools commands and subprocesses should not inherit validation state accidentally.
- Keep this work aligned with the broader subprocess API adoption roadmap so ReleaseTools does not introduce another transitional execution abstraction.
