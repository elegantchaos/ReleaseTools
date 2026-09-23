## Project Specific Rules

- This repository is a Swift package that provides the `rt` release automation CLI and package plugin.
- The tool can be refactored aggressively to work with the latest release version of Swift.
- New tool releases do not need to maintain backwards compatibility unless explicitly requested.

## Standard Rules

- Understand request boundaries and inspect the relevant code, tests, manifests, and documentation before editing.
- Apply DRY and a single source of truth; keep code modern, idiomatic, simple, explicit, and free of hidden coupling or speculative abstractions.
- Match scope to the request: keep focused fixes coherent; use codebase-wide cleanup for cleanup, review, modernisation, and consistency work.
- Update documentation when commands, workflows, configuration, or behaviour changes; describe the current state.
- Use red/green TDD for non-UI code and add or update deterministic tests for changed behaviour.
- Create previews for UI code when the platform supports them.
- Run the narrowest relevant validation first, then broaden the checks. `rt validate` is the canonical validation command; target mode runs the matching SwiftPM test target when present. Report skipped validation, gaps, and residual risk.
- Prefer trusted primary sources for technical decisions.
- Use portable path references: repository-relative paths inside this repository and `~/...` for shared resources. Avoid machine-specific absolute paths.
- When a required Mint-installed command is unavailable on `PATH`, try `~/.mint/bin/<command>` before treating it as missing.
- Keep `Extras/Journal/` as dated Markdown entries and update `Extras/Journal/index.md` when a work session produces useful context, research, prototype notes, findings, open questions, or implementation plans.
- Keep `Extras/Decisions/` as an explicit log of important decisions, with one Markdown file per decision. Check it when relevant before implementing new code.
- Never expose or commit credentials or secrets. Do not perform irreversible destructive actions without explicit approval.
- If unexpected workspace changes appear, pause and confirm direction.

## Skills

- Use the `coding-standards` skill for all coding work.
- Use the `swift` skill for Swift language, package, and API design guidance.
- Use the `swift-testing-pro` skill for Swift Testing work in `Tests/`.
- Use the `swift-validation` skill for post-change validation in this Swift repository.
- Use the `codex-git` skill for git and GitHub work.

To refresh this file, use the `refresh` skill.
