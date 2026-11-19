# UP1: Retain Upload Diagnostics

- **Status:** Proposed
- **Release:** Unassigned
- **Depends on:** nothing
- **Sources:** [Upload Failure and Roadmap Migration](../Journal/2026-11-19-upload-failure-and-roadmap-migration.md)

## Finish Condition

Every `rt upload` attempt, including uploads run by `rt submit`, saves the response and stderr under a distinct, durable location. Success, failure, retries and overlapping attempts preserve earlier records. Records stay available until manually deleted and survive routine build cleanup. The command prints where to find the current attempt's files and makes any failure to save them visible.

## Notes

Capture the tool's original response even if it is empty or cannot be decoded as a receipt. Verify that a failed attempt's evidence remains available after a successful retry for the same app and platform.
