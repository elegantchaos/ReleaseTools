# Post-upload TestFlight automation

## Goal

Add a new command that runs after `upload` and performs the remaining App Store Connect and TestFlight setup:

- Set TestFlight build details text.
- Assign the uploaded build to external TestFlight groups.
- Submit the build for TestFlight review.

## High-level tasks

1. Add a dedicated command, likely `testflight`, and register it in `RootCommand`.
2. Define CLI inputs for app/build identifiers, external groups, locale, and summary generation mode.
3. Resolve the current processed build and the previous portal build for comparison.
4. Generate TestFlight “What to Test” text from the release tag range with deterministic fallback behavior.
5. Execute the App Store Connect API sequence for localization, group assignment, and review submission.
6. Record receipts and print a concise final summary.
7. Add unit, mocked integration, and command-wiring tests.

## Notes

- The App Store Connect steps must remain separate API calls.
- If FoundationModels is unavailable in `auto` mode, fall back to deterministic summarization.
- Review submission and external-group assignment failures should remain hard failures.
