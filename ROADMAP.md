# Roadmap

High-level tasks for the next ReleaseTools improvements:

1. [Post-upload TestFlight automation](Extras/Roadmap/PostUploadTestFlightAutomation.md)
   Add a dedicated command for build-localization updates, external group assignment, and TestFlight review submission after upload processing completes.
2. [Platform argument expansion](Extras/Roadmap/PlatformArgumentExpansion.md)
   Extend platform-aware commands to accept multi-platform selection, consistent inference, and controlled multi-platform execution.
3. [Validate output shaping and log capture](Extras/Roadmap/ValidateOutputShapingAndLogCapture.md)
   Reduce `rt validate` terminal noise, keep actionable diagnostics visible, and always retain raw per-step logs.
4. [Existing TODO follow-ups](Extras/Roadmap/ExistingTodoFollowUps.md)
   Close smaller command-level follow-ups that are related to the larger workflow improvements.
5. [Swift configuration API adoption](Extras/Roadmap/SwiftConfigurationAPIAdoption.md)
   Replace direct `.rt.json` decoding with the newer Swift configuration API and preserve current ergonomics around workspace and project settings.
6. [Subprocess API adoption](Extras/Roadmap/SubprocessAPIAdoption.md)
   Replace the `Runner` dependency with Swift's newer subprocess APIs, or fold those APIs into `Runner` if that still provides meaningful ergonomics.
7. [Local configuration overlay](Extras/Roadmap/LocalConfigurationOverlay.md)
   Support a committed base configuration plus an uncommitted local overlay so sensitive keys such as `apiIssuer` and `apiKey` can stay out of source control.
