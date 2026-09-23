# Error Type Ownership

Errors meaningful only within one owner are nested in a same-file extension after that owner's primary definition. User-facing failures use `LocalizedError`, including errors passed to `Session.throwIfFailed`, which appends the subprocess stderr automatically. Conform to `Runner.Error` only when a description needs more of the session than stderr, such as stdout or the exit state.
