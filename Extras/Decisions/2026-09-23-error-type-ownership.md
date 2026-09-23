# Error Type Ownership

Errors meaningful only within one owner are nested in a same-file extension after that owner's primary definition. `Runner.Error` is reserved for errors passed to `Session.throwIfFailed`; user-facing workflow failures use `LocalizedError`.
