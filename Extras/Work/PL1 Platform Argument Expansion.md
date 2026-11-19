# PL1: Platform Argument Expansion

- **Status:** Proposed
- **Release:** Unassigned
- **Depends on:** nothing
- **Sources:** [Previous roadmap plan](https://github.com/elegantchaos/ReleaseTools/blob/1802a4efdb874f12f2ef492c48759967152d04cf/Extras/Roadmap/PlatformArgumentExpansion.md)

## Finish Condition

Platform-aware commands accept either a single platform or an ordered selection, infer the platform when needed and execute with predictable logs. Multi-platform submission keeps artifacts and receipts isolated per platform, with tests for selection, orchestration and aggregated errors.

## Delivery Outline

1. Refactor platform parsing into a shared selection abstraction that returns an ordered platform list.
2. Add `--platforms` parsing, canonicalization, de-duplication, and mutual exclusion with `--platform`.
3. Implement platform inference when neither option is supplied.
4. Add execution controls for series vs parallel work where the command is safe to fan out.
5. Update `submit` orchestration so multi-platform runs can execute per-platform or phase-by-phase.
6. Scope artifacts and receipts per platform to avoid collisions.
7. Add parsing, orchestration, and error-aggregation tests.

## Notes

- The default should stay conservative: explicit ordering, series execution, and predictable logs.
- Portal-assisted inference should remain optional to avoid surprising network dependencies in local workflows.
