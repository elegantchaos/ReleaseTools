# Existing TODO follow-ups

## Submit: open App Store Connect page after upload

### Goal

Add an optional way for `submit` to open the relevant App Store Connect page after a successful upload or post-upload workflow.

### High-level tasks

1. Add an opt-in flag such as `--open-portal` to `submit`.
2. Resolve the most useful destination page for the uploaded build or app.
3. Keep the behavior best-effort and non-fatal for local workflows.
4. Avoid enabling it by default so CI and automation remain safe.

### Notes

- This follow-up fits naturally beside the post-upload TestFlight workflow because both improve the post-upload verification path.
