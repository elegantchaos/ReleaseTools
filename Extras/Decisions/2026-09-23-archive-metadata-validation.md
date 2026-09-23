# Archive Metadata Validation

Release commands validate `archive.xcarchive/Info.plist` through a throwing `XcodeArchive` initializer. The archive filesystem remains the source of truth; `ReleaseEngine` does not cache parsed archive metadata.
