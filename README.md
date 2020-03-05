
# Release Tools

A suite of tools to perform various release-related tasks.

## Build Number

Example: `rt update-build --config=Sources/Configs/BuildNumber.xcconfig`


The `update-build` command is used to writ an `.xcconfig` file, the location of which is specified with the `--config=<path>` option.

Two variables are defined in this config: `BUILD_NUMBER` and `BUILD_COMMIT`.

The build number is a count of the commits (produced with `git rev-list --count HEAD`, and thus trends upwards as commits increase.

The commit value stored is the actual git commit at `HEAD`.

This xcconfig file can be included in other files, and the variables can be substituted into `Info.plist` for runtime access, or used in other ways by build scripts.

The way I typically use this command is to add a pre-build or pre-archive step to the scheme, to run it. Doing it from the scheme like this ensures that the xcconfig has been updated by the time any targets begin to build. 

This is important since the targets will read their xcconfigs once at the beginning of the build process, and (unsurprisingly) won't notice if they are altered during the build.

## Release Toolchain

The process of producing a release consists of a number of steps: archiving, notarizing, stapling, zipping, updating, regenerating an appcast, and publishing.  

When everything is working smoothly, the steps are expected to be run one after the other, without the need for interaction.

However, each step is broken down into separate command. This is done to make them easier to debug, and to make it possible to re-run some steps without having to start at the beginning each time.

A shell script to run them all together in the correct order might look something like:

```
set -e
rt archive --show-output
rt export
rt notarize
rt wait
rt compress
rt appcast --show-output
rt publish
```

More details of each command are given below:

### archive

Run `xcodebuild archive` to archive the application for distribution.

The scheme to build is either specified explicitly, or set previously using `--set-default`.

The archive is placed into: `.build/<platform>/archive.xcarchive`.

*Note:* `updateBuild` runs implicitly during the archiving process, to update `BuildNumber.xcconfig` with the latest build number.

*Note:* it is necessary to pass the `--show-output` flag to this command, because it needs to access the keychain. If you don't do this, the command will sometimes hang (I believe because it's waiting for you to enter a password to allow keychain access).


### export

Exports the application from the archive created with the `archive` command, and puts it into `/build/export`.

### notarize

Takes the app exported with the `export` command, zips it up, and uploads it to Apple for notarization.

If the upload succeeds, the Apple servers return an xml receipt containing a RequestUUID that we can use to check on the status later. This is stored in `.build/<platform>/export/receipt.xml`.

### upload

Takes the ipa exported with the `export` command, and uploads it to Apple Connect for review.

If the upload succeeds, the Apple servers return an xml receipt containing status message. This isn't of much use, but is stored in `.build/<platform>/export/receipt.xml`.

### wait

Requests the notarization status for the app from the Apple servers.

If the status is `success`, we copy the exported app from `.build/<platform>/exported` into `.build/<platform>/stapled`, and staple it with the notarization ticket.

If the status is `failed`, we abort with an error.

If the status is not yet known (notarization hasn't completed), we wait 10 seconds and check again.

This command will therefore not return until notarization has completed (or failed).

### compress

Compresses the app in `.build/<platform>/stapled` into a zip archive suitable for inclusion in the `appcast`.

This will have the name `<app>-v<version>-<build>.zip`, and will be copied into the location specified with the `--to=<path>` option.

A copy of the archive, with the name `<app>-latest.zip` is also placed in the location specified with the `--latest=<path>` option.

If these two locations aren't specified, we use the default layout, which is the equivalent of  `--to=Dependencies/Website` and `--latest=Dependencies/Website/updates`.

### appcast

Rebuilds the appcast file, using Sparkle's `generate_appcast` command, which it builds first if necessary.

The file is named `appcast.xml` and its location is specified with the `--to=<path>` option. 

If this option is not specified, we use the default layout, which is the equivalent of `--to=Dependencies/Website`.

The appcast is signed using a private DSA key which is expected to be in the keychain under the name `<scheme> Sparkle Key`.

If this key isn't found, it is generated, using Sparkle's `generate_keys` script, and imported into the keychain. Currently I can't find a way to give the imported key the right label, so this has to be done manually using the `Keychain Access` app.  

The public key is expected to be called `dsa_public.pem`, and be included in the `Resources/` folder of the app bundle.

In order to be able to build/run the various Sparkle tools, the Sparkle project is expected to be present in the Xcode workspace.

*Note:* it is necessary to pass the `--show-output` flag to this command, because it needs to access the keychain. If you don't do this, the command will sometimes hang (I believe because it's waiting for you to enter a password to allow keychain access).

### publish

Commits and publishes the latest changes to the website repo.

Assumes that the submodule defining the website which hosts the appcast is located at `Dependencies/Website`.



## Building

The tool is currently built using swift package manager: `swift build`.

You can build and run in a single line with `swift run ReleaseTools <command> <args>`.


## Naming Conventions

To cut down on the amount of configuration that you have to do, `rt` relies on naming conventions and defaults for a lot of things.

We expect a standard project layout. If your project is called `Foo`, the layout would be: 

```
Foo/
    Foo.xcworkspace
    Foo.xcodeproj
    Sources/
        Foo/
            Resources/
```
        
From this we derive some other values:
        
- *package*: this is expected to be the same name as the containing folder, so if your project is in a folder `~/Projects/foo`, the package will be `foo`.
- *workspace*: this is expected to be the same name as the package, so if your package is `foo`, the workspace will be `foo.xcworkspace`.
- *platform*: this is either supplied as `--platform=macOS|iOS|tvOS|watchOS` or defaults to `macOS`
- *scheme*: this is supplied as `--scheme=<name>`; a default can be saved by including `--set-default`. A different default can be set for each platform.
- *export options*: these are expected to be in `Sources/<package>/Resources/ExportOptions-<platform>.plist`.
