# Project Specific Rules

- This repository is a Swift package that provides the `rt` release automation CLI and package plugin.
- The tool can be refactored aggressively to work with the latest release version of Swift.
- New tool releases do not need to maintain backwards compatibility unless explicitly requested.
- Keep `Extras/Journal/` as dated Markdown entries and update `Extras/Journal/index.md` when a work session produces useful context, research, prototype notes, findings, open questions, or implementation plans.
- Keep `Extras/Decisions/` as an explicit log of important decisions, with one Markdown file per decision. Ask for explicit user confirmation before recording a decision. Check relevant decisions before implementing new code.

# Standard Rules

1. Locate the shared agents content before starting work. Use `~/.local/share/agents/` when available; otherwise obtain it from https://github.com/elegantchaos/Agents.
2. You must read @~/.local/share/agents/COMMON.md before starting work, and follow the instructions in it at all times (use `COMMON.md` from the GitHub copy when the local one is unavailable).
3. Resolve the skill names below from that same content, including skills provided by plugins.
4. For each skill required by the task, read its `SKILL.md` and every reference it marks as required before starting the work, and follow them. Required references are part of the skill's rules, not optional background.
5. Follow the guidelines in all code you write or change, even where the surrounding code does not.
6. Before reporting work complete, check each changed file against the required skills' checklists, and report the result and any exceptions.
7. Report any required guidance you cannot access.

- Follow the `baseline:standards` skill for all coding.
- Use the `baseline:review` skill for reviewing pull requests and completed work.
- Use the `baseline:records` skill for the development journal and decision log.
- Use the `baseline:git` skill for git and GitHub operations.
- Use the `swift:language` skill for all Swift code.
- Also use the `swift:testing` skill for Swift Testing work.
- Also use the `swift:concurrency` skill for actor isolation and shared mutable state.
- Use the `swift:validation` skill for post-change validation in this Swift repository.

To refresh this file, use the `baseline:refresh` skill.
