# Subprocess API adoption

## Goal

Move process execution onto Swift's newer subprocess APIs, either directly or via an updated `Runner` wrapper if it still provides worthwhile ergonomics over the standard library.

## High-level tasks

1. Review every current `Runner` use site and classify which capabilities are actually needed: streaming output, exit-status handling, environment overrides, and working-directory control.
2. Evaluate whether the current `Runner` package already exposes the new subprocess APIs with enough ergonomics to justify keeping it.
3. If not, prototype a direct subprocess abstraction in ReleaseTools that preserves current call-site clarity and testability.
4. Migrate one or two representative runners first, then expand the change across all command execution paths.
5. Revisit output capture and validation logging so the subprocess migration complements the roadmap work already planned for `rt validate`.

## Notes

- The decision should be based on net complexity, not on replacing a dependency for its own sake.
- Process execution is a cross-cutting concern, so the migration should avoid mixing multiple subprocess styles long term.
