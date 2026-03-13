# Swift configuration API adoption

## Goal

Adopt the newer Swift configuration API in place of direct `.rt.json` loading while preserving the existing configuration model and keeping migration costs manageable for current users.

## High-level tasks

1. Audit where configuration is loaded, validated, and merged today so the replacement is scoped correctly.
2. Model the current `.rt.json` fields in the new configuration API, including defaults and validation rules.
3. Decide whether the new API fully replaces `.rt.json` or whether a compatibility bridge is needed for a transition period.
4. Update command entry points and tests so configuration resolution goes through the new abstraction.
5. Document migration expectations, fallback behavior, and any new file naming or layout rules.

## Notes

- Backward compatibility matters because existing automation and repositories may already depend on `.rt.json`.
- This change overlaps with the local overlay work, so configuration layering should be designed once rather than retrofitted later.
