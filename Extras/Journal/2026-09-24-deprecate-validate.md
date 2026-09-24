# Deprecate Validate

Validation moved to AgentTools as `agt validate` (AgentTools 2.1.0), with the same options and behaviour; Xcode products go to `.build/agt-validate/DerivedData` there. `rt validate` stays for a transition period: it prints a deprecation warning to standard error on every run, and its abstract and usage text point to `agt validate`.

Removal is roadmap item 9. The two validate roadmap items (local Swift package validation, and moving validation subprocesses onto `Runner`) should be carried out in AgentTools, not here.
