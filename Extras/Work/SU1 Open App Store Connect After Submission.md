# SU1: Open App Store Connect After Submission

- **Status:** Proposed
- **Release:** Unassigned
- **Depends on:** nothing
- **Sources:** [Previous roadmap plan](https://github.com/elegantchaos/ReleaseTools/blob/1802a4efdb874f12f2ef492c48759967152d04cf/Extras/Roadmap/ExistingTodoFollowUps.md)

## Finish Condition

An opt-in option opens a useful App Store Connect page after successful submission. Browser launch is best-effort, and the default workflow remains suitable for CI.

## Delivery Outline

1. Add an opt-in flag such as `--open-portal` to `submit`.
2. Resolve the most useful destination page for the uploaded build or app.
3. Keep the behavior best-effort and non-fatal for local workflows.
4. Avoid enabling it by default so CI and automation remain safe.

## Notes

- This follow-up fits naturally beside the post-upload TestFlight workflow because both improve the post-upload verification path.
