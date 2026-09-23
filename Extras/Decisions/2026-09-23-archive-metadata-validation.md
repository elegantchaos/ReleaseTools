# Archive Metadata Validation

Release commands validate `archive.xcarchive/Info.plist` through a throwing `XcodeArchive` initializer. The archive filesystem remains the source of truth; `ReleaseEngine` does not cache parsed archive metadata.

Error types that belong to one owner are nested in a same-file extension after the owner's main definition. `Runner.Error` is reserved for errors passed to `Session.throwIfFailed`; user-facing workflow failures use `LocalizedError`.
