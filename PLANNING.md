# Planning

## Index

1. [New command: post-upload TestFlight automation](#new-command-post-upload-testflight-automation)
2. [Platform argument expansion (`--platform` + `--platforms`)](#platform-argument-expansion---platform--platforms)
3. [Existing TODO follow-ups](#existing-todo-follow-ups)

## New command: post-upload TestFlight automation

### Goal

Add a new command that runs after `upload` and performs the remaining App Store Connect/TestFlight setup:
- Set TestFlight build details text.
- Assign the uploaded build to external TestFlight groups.
- Submit the build for TestFlight review.

### Proposed command shape

- Command name: `testflight` (or `post-upload`, if you want the purpose to be explicit).
- Placement: `Sources/ReleaseTools/Commands/TestFlightCommand.swift`.
- Root registration: add to `RootCommand` subcommands.
- Optional integration: add a flag to `submit` to run this command automatically after `upload`.

### Inputs/options

- `--app-id <id>`: App Store Connect app ID.
- `--build-id <id>` (optional): if omitted, resolve latest processed build for current version/build number.
- `--external-group <id>`: repeatable external TestFlight group IDs.
- `--locale <id>`: localization key for TestFlight details (default `en-US`).
- `--via <mode>`: summarization mode; proposed values:
  - `auto` (default): use FoundationModels if available, otherwise deterministic trimming.
  - `foundation-models`: require FoundationModels path.
  - `deterministic`: never use FoundationModels.

### API sequence (separate calls, post-upload)

1. Resolve current uploaded build in App Store Connect.
2. Resolve previous build known to the portal for the same app (excluding current build).
3. Upsert `betaBuildLocalization` for current build (set details/what-to-test text).
4. Assign current build to each external beta group.
5. Create `betaAppReviewSubmission` for the current build.

Notes:
- These must be separate API calls.
- Calls should happen only after upload processing is complete (`valid`/processable build state).

### Build-details text generation plan

1. Read current git tag (`git describe --tags --exact-match HEAD` or configured release tag source).
2. Determine previous portal build tag:
   - Query prior App Store Connect build metadata and read an associated tag field, if present.
   - If no explicit tag field exists, define a stable mapping strategy (for example, infer from version/build metadata and local tag naming rules).
3. Collect commit messages in range:
   - `git log --pretty=format:%s <previous-tag>..<current-tag>`.
4. Summarize commit messages:
   - `--via auto`/`foundation-models`: if FoundationModels is available at runtime, produce a concise grouped summary.
   - Fallback or `--via deterministic`: compact deterministically (dedupe, trim prefixes, cap line length, cap item count, preserve order).
5. Write summary into TestFlight “What to Test” details text.

### Deterministic fallback rules (proposed)

- Normalize whitespace.
- Remove exact duplicate subjects.
- Collapse known prefixes (`fix:`, `feat:`, `chore:`) for readability.
- Limit each line to a fixed length (for example 100 chars).
- Limit total lines (for example 12), append `+N more` when truncated.

### Error handling

- Hard fail when:
  - Current build cannot be resolved.
  - No external groups were valid/assignable.
  - Review submission API returns errors.
- Soft fail with warning when:
  - Previous build tag cannot be determined (fall back to short generic details text).
  - FoundationModels requested but unavailable and `--via auto` was used (switch to deterministic).
- If `--via foundation-models` is explicitly requested and unavailable, fail with actionable error.

### Observability

- Log each App Store Connect step and endpoint intent (without leaking secrets).
- Save API request/response receipts in build output folder, similar to existing upload receipts.
- Print final summary of:
  - build ID used
  - previous tag resolved
  - groups assigned count
  - review submission ID/state

### Test plan

- Unit tests:
  - Commit range extraction and deterministic summarization output.
  - Previous-tag resolution logic from mocked portal responses.
  - `--via` mode selection behavior.
- Integration-style tests (mocked HTTP transport):
  - Successful end-to-end API call ordering.
  - Partial failures and retry-safe behavior.
- Command wiring tests:
  - Root command registration.
  - Optional `submit` chaining behavior.

## Platform argument expansion (`--platform` + `--platforms`)

### Goal

Expand relevant commands so they accept either:
- `--platform <single>` (current behavior), or
- `--platforms <list>` (new behavior; comma-separated and/or repeatable entries).

Commands should execute once per resolved platform, either in series or parallel depending on command safety and dependencies.

### Scope (relevant commands)

- Commands that currently use `PlatformOption` and perform platform-specific work (for example `archive`, `export`, `upload`, `submit`, and any command that talks to platform-specific tooling/endpoints).
- Keep non-platform-dependent commands unchanged.

### CLI behavior

- Mutual exclusivity rules:
  - Allow either `--platform` or `--platforms`.
  - Error if both are supplied together.
- Defaulting:
  - If neither is provided, attempt platform inference before falling back to current default.
- Parsing:
  - Normalize synonyms/aliases into canonical platform IDs.
  - De-duplicate while preserving user-specified order.

### Platform inference when no explicit platform input is provided

- Inference priority:
  1. Inspect project/workspace build settings for supported destinations/platform SDKs.
  2. Inspect active `.xcconfig` files (global + configuration-specific) for platform constraints.
  3. Optionally query App Store Connect to infer distributed platforms for the app.
  4. If still ambiguous, fall back to existing single-platform default.
- Local inference details:
  - Read relevant Xcode settings (for example SDK/target-family signals) from the selected scheme/targets.
  - Parse `.xcconfig` values currently in effect for the command invocation.
  - Return a stable, ordered unique platform list.
- Portal-assisted inference (optional):
  - Use App Store Connect metadata only as a secondary signal when local config is inconclusive.
  - Gate behind an opt-in flag (for example `--infer-platforms-from-portal`) to avoid unexpected network/API dependency in local workflows.
- Logging:
  - Always log whether platforms were explicit or inferred.
  - When inferred, log the source used (`project`, `xcconfig`, `portal`, `default`).

### Execution model

- Introduce an execution mode option for multi-platform runs:
  - `--execution series` (default): one platform at a time.
  - `--execution parallel`: run independent platform tasks concurrently.
- Guardrails:
  - Commands with shared mutable outputs should default to series unless output paths are platform-isolated.
  - Parallel mode should fail fast on first critical error and cancel remaining tasks where safe.

### Submit command orchestration

`submit` currently chains subcommands (`archive -> export -> upload`) for one platform. For multiple platforms, support explicit orchestration strategy:
- `--submit-order per-platform`:
  - Complete full pipeline for platform A, then platform B, etc.
- `--submit-order phase-by-phase`:
  - Run `archive` for all platforms, then `export` for all, then `upload` for all.
- Optional parallel variants:
  - `per-platform-parallel`: each platform runs full pipeline concurrently.
  - `phase-by-phase-parallel`: each phase fans out across platforms concurrently.

Recommended default: `per-platform` in series for predictable logs and lower risk.

### Implementation notes

- Refactor `PlatformOption` into a platform selection abstraction returning `[Platform]`.
- Add helper runner utilities for:
  - serial iteration with consistent logging prefixes (`[ios]`, `[macos]`, etc.),
  - bounded parallel execution for async commands.
- Ensure all artifact/output paths are platform-scoped to avoid collisions.
- Record per-platform receipts/log files in separate subfolders.

### Failure semantics

- Series mode:
  - stop on first failure by default.
- Parallel mode:
  - collect per-platform failures and report a combined error summary.
- Optional future flag:
  - `--keep-going` to continue remaining platforms after failures.

### Test plan

- Option parsing tests:
  - `--platform` vs `--platforms`, mutual exclusion, de-duplication, defaults.
- Command behavior tests:
  - Single-platform parity with existing behavior.
  - Multi-platform series ordering.
  - Multi-platform parallel execution and error aggregation.
- `submit` strategy tests:
  - `per-platform` and `phase-by-phase` ordering verification.

## Existing TODO follow-ups

### `submit`: open App Store Connect page after upload

- Source: `/Users/sam/Developer/Projects/ReleaseTools/Sources/ReleaseTools/Commands/SubmitCommand.swift:45`
- Current TODO: `open page in app portal?`
- Why it belongs in planning:
  - It is directly related to the new post-upload/TestFlight workflow.
  - It impacts user experience for verification and manual fallback steps.
- Proposed plan:
  - Add optional flag on `submit` (for example `--open-portal`) to open the relevant App Store Connect build/app page after successful upload or post-upload automation.
  - Keep default as non-opening behavior for CI safety.
  - Implement as best-effort/non-fatal behavior with clear logging.
