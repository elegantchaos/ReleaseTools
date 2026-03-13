# Platform argument expansion

## Goal

Expand relevant commands so they accept either a single `--platform` or a multi-value `--platforms` input, then execute per resolved platform with predictable ordering and logging.

## High-level tasks

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
