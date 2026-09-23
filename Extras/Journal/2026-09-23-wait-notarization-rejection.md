# Wait Notarization Rejection

`rt wait` used to poll forever after an `invalid` notarization status, because the rejection went to `ReleaseEngine.fail`, which nothing read. `WaitForNotarizationCommand.status(fromResponse:loadLog:)` now parses the status response as a pure function, and `check` throws `Error.notarizationFailed` with the full report. `run()` rethrows the command's own errors instead of wrapping them as `fetchingStatusFailed`. `ReleaseEngine.fail` and `ReleaseEngine.error` have been removed.

The status tests use synthetic `altool` responses; the parsing has not been exercised against a live rejection.
