## Project Specific Rules

- This repository is a Swift package that provides the `rt` release automation CLI and package plugin for archiving, exporting, uploading, notarizing, and tagging application releases.

## Standard Rules

- Inspect the relevant code, tests, manifests, and docs before editing, then apply the smallest coherent change set that keeps a single source of truth and avoids duplication.
- Keep implementations simple, avoid speculative work, and avoid unrelated refactors during focused tasks.
- Add or update tests for behavior changes and use red/green TDD for non-UI code.
- Run the narrowest validation that proves the change first, then broaden out to the relevant project checks, and report any skipped validation with the reason and residual risk.
- Use trusted primary sources for technical decisions when behavior, APIs, or policy are uncertain.
- Use portable path references in docs and guidance. Prefer repository-relative paths for files in this repository and `~/...` home-relative paths for shared resources outside it. Avoid machine-specific absolute paths.
- Never expose or commit credentials or secrets.
- Do not perform irreversible destructive actions without explicit approval.
- If unexpected workspace changes appear, pause and confirm direction before proceeding.

## Skills

- Use the coding-standards skill for cross-language engineering policy, maintainability, and source-selection guidance.
- Use the swift skill for baseline Swift language, package, and API design guidance.
- Use the swift-testing-pro skill for Swift Testing work in `Tests/`.
- Use the validation-flow skill for post-change validation in this Swift repository.

To refresh this file, use the refresh-agents skill.
