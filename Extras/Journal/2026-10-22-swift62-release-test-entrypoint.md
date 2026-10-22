# Swift 6.2 release-test entry point failure

Inspected PR #18 checks at commit `0da7838`. Swift 6.2 jobs fail; Swift 6.4 jobs
build and test successfully. The failing PR job resolves Swift 6.2 to 6.2.4.

Run: https://github.com/elegantchaos/ReleaseTools/actions/runs/39750012334/job/119727926000

The release executable builds successfully. The release test executable also
compiles and links, then reports:

```text
Error: Unknown option '--test-bundle-path'
Usage: rt [--version] <subcommand>
```

No tests start. The downloaded raw `swift-test-swift-testing-release.log` contains
this error after `Build complete!`; xcbeautify hides it in the displayed Actions
output, leaving only input-verification warnings. Those warnings also occur in
the successful executable build and do not explain the test failure.

The test target depends on the executable target, which declares `@main
RootCommand`. This matches upstream SwiftPM issue #9741, whose Swift 6.2.4 release
reproduction shows the generated test runner's entry point resolving to the
ArgumentParser executable's entry point. Swift Testing's `--test-bundle-path`
argument consequently reaches the application's argument parser.

Upstream diagnosis and recommended target split:
https://github.com/swiftlang/swift-package-manager/issues/9741

A structural fix is to move testable code into a library target, retain a thin
executable entry point, and make tests depend on the library. CLI integration
tests still need the executable built alongside the tests, so preserve explicit
build coverage when changing the dependency graph. No source/workflow change was
made during this diagnosis; no local Swift 6.2 toolchain was available to rerun it.

## Swift 6.3 baseline experiment

The user requested raising `swift-tools-version` to 6.3 and checking the resulting
CI push. ActionBuilder derives its compiler set from the package tools version
when no explicit compiler set is configured, adding the latest supported release.
Running ActionBuilderTool 2.2.6 with the updated manifest generated Swift 6.3 and
6.4 jobs and refreshed the README badges.

Local `agt format` and `agt validate --fast` passed (65 tests); `actionlint` and
`git diff --check` passed. The local compiler is Swift 6.4. The remote Swift 6.3
release-test job is the verification of whether this baseline avoids the failure.
