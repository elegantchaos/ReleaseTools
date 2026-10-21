# Agent Guidance Refresh

Refreshed `AGENTS.md` using the canonical local `baseline:refresh` template and shared content at `~/.local/share/agents/`. The original project-specific rules are preserved verbatim. Existing journal and decision-log policies were moved into the project-specific section without changing their wording.

The standard section imports `COMMON.md` and selects the current baseline standards, review, records, and Git skills, plus Swift language, testing, concurrency, and validation skills. Stack selection is based on `Package.swift`, Swift command sources, and Swift Testing suites. UI and non-Swift language skills are not selected.

Verified exact template rendering, preserved policy text, all eight skill references, and absence of legacy Claude instruction files. No new project-record policies or decisions were added. No shared resources were changed. `git diff --check` passed; code validation was not repeated for this documentation-only refresh. The preceding upload-error changes passed fast validation with 66 tests.
