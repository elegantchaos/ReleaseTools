# Existing Tag Error

`rt tag` reported a duplicate version tag by interpolating `ReleaseEngine.BuildInfo`, exposing its stored-property dump and the full commit hash. The error now names the tag directly: `A version tag already exists at HEAD: v1.0.0-267.` Tag creation and duplicate-tag detection are unchanged.

A focused regression test verifies the exact localized message using the reported version, build, and commit. It failed against the original error formatting before the change. The README describes the rejection and the command's local tag creation behavior. Documentation comments were completed in the changed engine file.

Validation passed: the focused regression test, `agt format`, `agt validate --fast` (build and all 67 tests), and `git diff --check`. One existing lint warning remains in `XcodeArchiveTests.swift`. Full validation was not run; changes are uncommitted on `feature/readable-existing-tag-error`.
