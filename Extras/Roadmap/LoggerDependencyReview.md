# Logger dependency review

## Goal

Decide whether ReleaseTools still needs Logger, and replace it with something smaller if not.

## Background

Logger was added with the idea that `--verbose` would turn verbose log channels on and off. That turned out to be overkill: `ReleaseEngine.log` and `verbose` now just `print`, and ReleaseTools creates no channels. The only remaining use is `await Manager.shared.shutdown()` in `RootCommand.main()`, which flushes channel output before exit. It was added after log output was lost on exit (see `a16affd`).

The package requires `from: "2.0.0"`. Logger 3.0 is source-compatible with that call, and its `shutdown()` now waits for every channel to drain.

## High-level tasks

1. Confirm that nothing else depends on Logger, directly or through another package.
2. Move diagnostic and progress output to `stderr`, following the usual CLI convention, and keep `stdout` for results that scripts consume.
3. Remove the Logger dependency and the shutdown call, unless a real need for named diagnostic channels emerges.
4. Consider a small package shared by ReleaseTools and AgentTools, with common CLI support such as `stderr` output and verbose/quiet handling. AgentTools has no logging dependency today and already flushes `stdout` by hand in places.

## Notes

- Any shared package should earn its place: two tools with the same few helpers may be better served by copying them than by another dependency.
- If Logger is kept for diagnostics, update to 3.x so the shutdown actually waits for output to drain.
