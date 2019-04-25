# Release Tools

A fairly random suite of tools to perform various release-related tasks,

Current tools:

- appcast
- archive:
- compress
- export
- publish
- updateBuild


## Appcast

Rebuilds the appcast file.

Assumes that the submodule defining the website which hosts the appcast is located at `Dependencies/Website`.

## Archive

Run `xcodebuild archive` to archive the application for distribution.

The scheme to build is either specified explicitly, or set previously using `--set-default`.

## Compress

Compresses the output of the `export` command into a zip archive suitable for inclusion in the `appcast`.

## Export

Exports the output of the `archive` command as something suitable for distribution outside of the Apple storew (eg with Sparkle).

## Publish

Commits and publishes the latest changes to the website repo.

Assumes that the submodule defining the website which hosts the appcast is located at `Dependencies/Website`.

## UpdateBuild

Outputs the `Configs/BuildNumber.xcconfig` file, containing a build number derived from the count of git commits.
