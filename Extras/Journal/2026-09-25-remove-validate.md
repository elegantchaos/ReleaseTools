# Remove Validate

Removed `rt validate`, now that `agt validate` in AgentTools covers it. `ValidateCommand`, `Sources/ReleaseTools/Validation/`, the discovery tests, the README section and the two validate roadmap items (local Swift package validation, validation process cleanup) are gone; that work lives in AgentTools. `AGENTS.md` now names `agt validate` as the validation command.
