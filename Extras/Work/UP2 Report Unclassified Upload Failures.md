# UP2: Report Unclassified Upload Failures

- **Status:** Proposed
- **Release:** Unassigned
- **Depends on:** [UP1: Retain Upload Diagnostics](UP1%20Retain%20Upload%20Diagnostics.md)
- **Sources:** [Upload Failure and Roadmap Migration](../Journal/2026-11-19-upload-failure-and-roadmap-migration.md)

## Finish Condition

When `altool` fails without a usable structured rejection, `rt` exits unsuccessfully and reports the exit status, useful tool output when available, and the location of the saved response and log. Structured rejections continue to show their existing diagnostics. When the evidence points to pending compliance questions, the message tells the user where to check in App Store Connect.

## Notes

Exercise a fixture with the reported `ExitFailure (31)` line and no usable receipt. That line alone leaves the reason unknown. Add specific compliance guidance when a captured response or another reliable signal supports it.
