# SketchX

A simple tool to help with exporting Sketch documents to Xcode asset catalogues.

*Note*: This tool can be run manually, but is really intended to be run from a Run Script phase in Xcode, as part of your build.



## Usage

### Single Catalogue

To export all artboards on a page to an asset catalogue of the same name:

    `sketchx Document.sketch <page> <path>`

Each artboard on the page will be exported into the catalogue.

The artboard name should be set in Sketch to reflect the name and type of the asset - for example "AppIcon.appiconset/AppIcon".

Export presets should be set up for each size/scale variation that you require.

The catalogue will be exported into the location specified by `<path>`.

### Renaming

If you want to use a catalogue name for a page, you can specify it along with the page name:

    `sketchx Document.sketch <page>=<catalog> <path>`

### Multiple Catalogues

To export multiple pages in a single go, supply a comma-delimited list of page names:

    `sketchx Document.sketch "macOS,iOS" Assets/`

In the example above, the pages called "macOS" and "iOS" will be exported to `Assets/macOS.xcassets` and `Assets/iOS.xcassets` respectively.

### All Pages

Alternatively you can leave out the page name to export all pages:

    `sketchx Document.sketch <path>`

*Note*: this will skip any page called "Symbols". If you have a page called Symbols that you want to export, you'll have to name it explicitly.



## Building

Fetch the contents of this repository with `git clone https://github.com/elegantchaos/SketchX.git`.

Build and run, using `swift run sketchx`.

After doing this, the built executable can be found in `.build/debug/sketchx`.



## Installing

If you want to install the executable somewhere, you can just build then copy it:

```
    swift build
    sudo cp .build/debug/sketchx /usr/local/bin/
```

That said, you may be better off just using `swift run sketchx` in your scripts, to ensure that you've always got the latest built copy locally.



## Example

If you have a catalogue called "Assets.xcassets", containing an icon set called "AppIcon", and an image set called "Image".

To export into this from Sketch:

- Call your page "Assets".
- For the iconset, make artboards called `AppIcon.appiconset/Icon16`, `AppIcon.appiconset/Icon32`, etc.
- For the image, make artboards called `Image.imageset/Image`, `Image.imageset/Image@2x`, etc.

An example document can be seen in `Example/Example.sketch`.

You can modify it and then export with the following command (from the root SketchX folder):

    `swift run sketchx Example/Example.sketch Assets Example/Example/`


Try modifying the Sketch document and re-exporting; you should see the assets change in Xcode.



## Contents.json

For now, `sketchx` doesn't write the `Contents.json` file for you, so you can't use it to create new catalogues/sets.

You have to create the structure first up in Xcode, use `sketchx` to do an initial export of images. The images you've
exported will then show up, unassigned, in the Xcode user interface. You can then drag them into the various slots
in the image/iconset. Once you've done this, Xcode will remember the assignments. Running `sketchx` again will just
re-export the images, with no further adjustments required in Xcode.



## Future

This is a quick & dirty hack, which could be improved.

Some ideas:

- write the Contents.json and create the complete structure if it's missing
- add a Sketch plugin which downloads/builds/runs this tool from within Sketch
