# Local Swift package validation

## Goal

Teach `rt validate` to support local multi-package SwiftPM development without requiring developers to manage `swift package edit` state manually.

The workflow should let publishable package manifests keep normal URL and version dependencies, while validation can temporarily resolve sibling packages from local checkouts under `Dependencies/`.

## High-level tasks

1. Add a checked-in but disposable root `Package.swift` generation step for repository-wide local package integration checks.
2. Generate the root package from the contents of `Dependencies/` by default, with optional configuration only for exceptions such as excludes, executable packages, or product filters.
3. Make `rt validate` rewrite the generated root package before the broad local package validation step, then fail if the checked-in generated file is stale.
4. Preserve `rt validate --target <package-or-target>` as a fast package-local validation path for coordinated package development.
5. For targeted validation, copy the target package's real `Package.swift` to a temporary `Package@swift-6.swift` manifest and rewrite only dependency declarations whose identities match local sibling packages.
6. Run targeted SwiftPM commands with `--package-path Dependencies/<Package>` so the package remains the validation root while the temporary version-specific manifest supplies local dependency overrides.
7. Always remove temporary `Package@swift-*.swift` files after validation, including failed validation, and add ignore-file guidance so stale override files are not committed accidentally.
8. Keep `swift package edit` out of the normal workflow; if it is ever used internally, isolate it to ReleaseTools-managed scratch state that is cleaned up automatically.
9. Add diagnostics that show which dependencies were resolved locally, which remained remote, and which configured or discovered packages were skipped.
10. Add tests for dependency identity matching, generated root manifest output, targeted manifest rewriting, cleanup behavior, and validation command selection.

## Notes

- `Package.resolved` should not be used for local overrides. It records resolved remote pins and does not change manifest dependency requirements.
- The temporary version-specific manifest should be created by copying the real manifest first, then applying a minimal dependency rewrite. This preserves package-specific platforms, products, targets, resources, plugins, traits, and Swift settings.
- Prefer `Package@swift-6.swift` over a minor-version-specific file unless ReleaseTools needs different behavior for a particular Swift minor version.
- The root package is an integration check for the local checkout. Targeted validation is a fast package-local check that still resolves local sibling changes when they exist.
- Xcode local package overrides remain the preferred Xcode workflow; this work is for SwiftPM and ReleaseTools validation paths.
