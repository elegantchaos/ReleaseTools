# ReleaseTools Roadmap

ReleaseTools automates building, signing and distributing Apple-platform releases. The [Release Plan](Extras/Documentation/Release%20Plan.md) indexes open work, and the [journal](Extras/Journal/index.md) records what happened.

## Release Direction

- **App Store Connect workflow.** Extend release automation through TestFlight review and make it easier to open the relevant portal page after submission.
- **Upload diagnostics.** Keep the evidence from each upload attempt and make failures actionable when Apple returns sparse diagnostics.
- **Multi-platform releases.** Make platform selection and execution predictable when releasing to several platforms.
- **Process execution.** Evaluate Swift's subprocess APIs and adopt them where they simplify command execution.
- **CLI diagnostics.** Review the Logger dependency and clarify which output belongs on stderr and stdout.

Update this roadmap when a goal is delivered or release scope changes. Track individual items and their order in the [Release Plan](Extras/Documentation/Release%20Plan.md).
