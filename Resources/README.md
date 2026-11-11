# Resources

This folder is currently mixed. Most of it is **legacy Objective-C Flycut
artwork** (`jumpcut.icns`, the `net.sf.jumpcut.*` and `com.generalarcade.*`
PNGs and TIFFs, the preferences toolbar images) which the Pastry rewrite
deletes along with the rest of the Objective-C tree.

The app icon bundle itself has moved out of here to `Pastry/Pastry.icon`,
where the Xcode project can see it. One thing left here is **new and must
survive that deletion**:

| Path | What it is |
|---|---|
| `icon/` | The vector sources, the script that builds `Pastry/Pastry.icon`, and the script that renders it for review. |

## How the icon was produced

The artwork is generated from parametric geometry rather than drawn by hand, so
shapes can be re-proportioned by changing a number. `icon/build_icon.py` turns
that geometry into the bundle, assigning the layer grouping, the colours and
the light/dark appearance variants.

```sh
cd Resources/icon
python3 build_icon.py       # regenerates Pastry/Pastry.icon
python3 preview_icon.py     # renders the bundle to icon/pastry-icon.png
```

`preview_icon.py` reads the built bundle rather than the generator, so it also
serves as a check that `icon.json` and the layer SVGs agree.

Full detail — the design, the colour convention, the layer grouping, what has
been verified mechanically and what still needs a human in Icon Composer — is
in [`icon/README.md`](icon/README.md).

The icon is not yet referenced by the Xcode project; wiring it into the target
is feature 10 of the rewrite plan.

Note that the menu-bar status item glyph is a **separate** asset — a flat
monochrome SF Symbol template, because macOS requires menu bar items to be
template images. It is not this icon.
