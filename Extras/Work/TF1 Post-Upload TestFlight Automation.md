# TF1: Post-Upload TestFlight Automation

- **Status:** Proposed
- **Release:** Unassigned
- **Depends on:** nothing
- **Sources:** [Previous roadmap plan](https://github.com/elegantchaos/ReleaseTools/blob/1802a4efdb874f12f2ef492c48759967152d04cf/Extras/Roadmap/PostUploadTestFlightAutomation.md)

## Finish Condition

A dedicated post-upload command can update the processed build’s localized TestFlight details, assign external groups and submit for review. It records receipts and reports the outcome. Command wiring, summary fallback and the API sequence are covered by tests.

## Delivery Outline

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
