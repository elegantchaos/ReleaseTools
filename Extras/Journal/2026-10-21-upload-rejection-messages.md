# Upload Rejection Messages

Bookish's upload receipt contained error 90301: "This bundle is invalid. Apple is not currently accepting applications built with this version of Xcode." The command displayed only the first sentence because `UploadReceiptError.compactMessage` truncated general messages at the first period. Apple's supplementary failure reason contained only `n/a` and a rejection ID.

General rejection summaries now preserve the complete primary message. The focused sandbox and already-released-version diagnostics remain in place, and supplementary failure reasons retain Apple's diagnostic IDs. The upload documentation describes the saved JSON response and stderr paths.

Regression coverage exercises a synthetic version of the rejected Xcode receipt through upload-output analysis, alongside full-message assertions for generic invalid bundles and standalone closed release trains. These assertions failed before the formatter change. No live upload is required to exercise the reporting path.

Validation passed: all seven upload tests, `agt format`, `agt validate --fast` (build and 64 tests), and `git diff --check`. Formatting reported one existing lint finding in `XcodeArchiveTests.swift`; the build reported a nullability warning in the `swift-subprocess` dependency. Comprehensive validation and a live Apple upload were not run.

## Tailored Xcode rejection

The user requested focused guidance for the unsupported-Xcode error. The receipt's `tool-version` identifies altool, not Xcode. Its `tool-path` identifies the upload application as `Xcode-27.2.0-Release.Candidate.app`; the receipt does not explicitly identify the toolchain that built the submitted app.

Error 90301 with Apple's unsupported-Xcode message now reports "Xcode version not accepted by App Store Connect", includes the upload application's filename when available, and instructs the user to rebuild and export with an accepted Xcode version before retrying. Generic supplementary diagnostics are suppressed for this recognized failure; the original receipt remains saved. Unrecognized failures retain the full Apple message.

The regression test covers versioned application names, plain `Xcode.app`, and paths without an application bundle. A separate case ensures other messages with code 90301 retain their original explanation. The tailored-output assertions failed before implementation.

Follow-up validation passed: all eight upload tests (including three Xcode-path cases), `agt format`, `agt validate --fast` (build and 65 tests), and `git diff --check`. The existing lint finding remains outside the changed files. Comprehensive validation and a live upload were not run.

## Compact version and build

The user requested a single-line rejection containing Xcode's exact version and build. The upload application's `Contents/version.plist` provides `CFBundleShortVersionString` and `ProductBuildVersion`. The installed application identified by Bookish's receipt reports `27.2` and `27B48`; its `CFBundleVersion` (`25400.60.4`) is not the product build identifier.

Unsupported-Xcode reporting now reads these values from the application containing the receipt's `tool-path`, producing `[90301] Xcode version 27.2 (27B48) not accepted by App Store Connect.` Application filenames and rebuild instructions are omitted. Missing, malformed, wrongly typed, or incomplete metadata produces the same compact rejection without a version. Other rejection types do not read the application metadata.

The revised output assertions failed before the implementation change. Focused tests pass using temporary application bundles and cover both versioned and plain application names, paths outside application bundles, and seven metadata failure cases.

Validation passed: nine focused tests, `agt format`, `agt validate --fast` (build and 66 tests), and `git diff --check`. One existing lint finding remains in `XcodeArchiveTests.swift`. Comprehensive validation and a live upload were not run.

The user subsequently requested removal of the numeric prefix from the tailored Xcode rejection. Its summary now reads `Xcode version 27.2 (27B48) not accepted by App Store Connect.` Updated exact-output tests cover both the versioned message and its metadata-unavailable fallback. Generic errors retain their numeric codes. The initial focused test command was blocked during manifest evaluation by `sandbox_apply: Operation not permitted`.

After removing the prefix, `agt format`, `agt validate --fast` (build and 66 tests), and `git diff --check` passed. The existing unrelated lint warning remains.
