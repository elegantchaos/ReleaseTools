# Validate output shaping and log capture

## Goal

Make `rt validate` useful in large Xcode workspaces by reducing terminal noise while preserving complete logs for debugging.

## High-level tasks

1. Add an output mode option with `filtered`, `quiet`, and `raw` behavior.
2. Print stable step banners plus short PASS/FAIL/SKIP result lines.
3. Capture complete subprocess output to per-step log files instead of placeholder log markers.
4. Filter live `xcodebuild` output down to actionable diagnostics such as `error:`, `warning:`, `note:`, and build completion markers.
5. Suppress known-noisy diagnostics like compiler-version remark spam.
6. Show a short extracted diagnostics block on failure, then point to the raw log path.
7. Print a compact end-of-run summary listing completed steps, warnings, and failed-step log locations.
8. Add tests for output parsing, filtering, log capture, and failure extraction.

## Notes

- Start with conservative line-based filtering instead of fragile parser logic.
- The first implementation should focus on `xcodebuild`; the same shaping can later expand to noisier SwiftPM steps if needed.
