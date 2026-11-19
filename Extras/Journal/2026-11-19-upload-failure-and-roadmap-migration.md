# Upload Failure and Roadmap Migration

On 19 November 2026, `rt upload` reported `Error: Upload failed with an unknown error.` and `altool` logged `ExitFailure (31)`. The submission succeeded on retry after Sam answered new compliance questions in App Store Connect. The failed response and log were unavailable for inspection, so the cause remains unconfirmed. The documented upload paths currently hold one receipt and one stderr log per platform.

The [Release Plan](../Documentation/Release%20Plan.md) indexes the five existing roadmap plans as work items and adds [UP1: Retain Upload Diagnostics](../Work/UP1%20Retain%20Upload%20Diagnostics.md) and [UP2: Report Unclassified Upload Failures](../Work/UP2%20Report%20Unclassified%20Upload%20Failures.md). UP1 gives UP2 durable evidence to point to. The [October full-project review](../Reviews/Full%20Review%202026-10-21.md) moved to the reviews folder with its findings awaiting disposition.
