# 4.0

Build number calculation has been reworked, and now always uses version tags.

Version tags are now platform-agnostic, and have the form `vX.Y.Z-BUILD`.

Running `rt archive` or `rt submit` will now check first for the presence of a version tag at the HEAD commit, and will refuse to run if there isn't one.

Running `rt tag` will create a new version tag. The version will be assumed to be the same as the previous tag, unless it is explicitly provided with the `--explicit-version` option. The build number will be incremented from the previous tag. If old platform-specific tags are found, they are included in the calculation to find the newest build number.

The `rt tag` command will refuse if there's already a tag.