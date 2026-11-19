# SP1: Subprocess API Adoption

- **Status:** Proposed
- **Release:** Unassigned
- **Depends on:** nothing
- **Sources:** [Previous roadmap plan](https://github.com/elegantchaos/ReleaseTools/blob/1802a4efdb874f12f2ef492c48759967152d04cf/Extras/Roadmap/SubprocessAPIAdoption.md)

## Finish Condition

ReleaseTools uses Swift’s newer subprocess APIs through a consistent approach, either directly or through Runner. The migration preserves the output, exit, environment and working-directory behavior each caller relies on.

## Delivery Outline

1. Review every current `Runner` use site and classify which capabilities are actually needed: streaming output, exit-status handling, environment overrides, and working-directory control.
2. Evaluate whether the current `Runner` package already exposes the new subprocess APIs with enough ergonomics to justify keeping it.
3. If not, prototype a direct subprocess abstraction in ReleaseTools that preserves current call-site clarity and testability.
4. Migrate one or two representative runners first, then expand the change across all command execution paths.

## Notes

- The decision should be based on net complexity, not on replacing a dependency for its own sake.
- Process execution is a cross-cutting concern, so the migration should avoid mixing multiple subprocess styles long term.
