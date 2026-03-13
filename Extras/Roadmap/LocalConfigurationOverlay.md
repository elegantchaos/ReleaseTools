# Local configuration overlay

## Goal

Allow ReleaseTools to combine a committed shared configuration with an uncommitted local overlay so teams can keep repository defaults in source control without committing sensitive values such as `apiIssuer` and `apiKey`.

## High-level tasks

1. Define the layering model: base config, local overlay, precedence rules, and behavior when only one file exists.
2. Choose the file naming and discovery rules for the local overlay, including ignore-file guidance for Git.
3. Make sure secret-bearing keys can live only in the overlay while non-sensitive defaults remain commit-friendly.
4. Update configuration loading, diagnostics, and tests to show the resolved source of values and catch invalid merges.
5. Document the recommended team workflow for checked-in defaults plus per-developer or per-machine secrets.

## Notes

- This should work whether the project keeps `.rt.json` or moves to the new Swift configuration API.
- Clear precedence and error messages matter; configuration layering becomes hard to debug quickly if source resolution is implicit.
