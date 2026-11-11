# Pastry app icon — concept sources

Vector sources for the Pastry app bundle icon. This is **not** the menu-bar
glyph (that is a flat monochrome SF Symbol template, a separate asset).

Status: **four concepts, awaiting a decision.** Once one is chosen, the real
`.icon` bundle is produced from the same geometry.

## Files

| File | What it is |
|---|---|
| `concepts.py` | The geometry. Emits every concept's layers as SVG path data on stdout as JSON. Single source of truth for the shapes. |
| `contact_sheet.py` | Builds `sheet.svg` from that JSON: each concept at 320 / 128 / 64 / 32 / 16 pt, in both appearances. |
| `concepts.png` | The rendered contact sheet, checked in so the concepts are reviewable without running anything. |

## Regenerating

```sh
cd Resources/icon
python3 concepts.py > geom.json
python3 contact_sheet.py            # writes sheet.svg
rsvg-convert -o concepts.png sheet.svg
```

Only `rsvg-convert` (librsvg) is external; everything else is stdlib Python 3.
Any SVG rasteriser works — `magick`, `qlmanage -t`, or opening `sheet.svg` in a
browser.

## Why the shapes are generated rather than hand-drawn

The marks are built from a few parametric primitives — `tapered_arc` for the
croissant crescents, `round_poly` for chamfered slices, `blade`/`ring` for the
scissors. Keeping them as parameters means a shape can be re-proportioned
(thicker crescent, wider cut gap, different taper) by changing a number instead
of re-drawing Bézier handles, and the output stays exactly reproducible.

Coordinates are emitted on the **1024×1024** canvas Icon Composer expects, so
the generated paths drop straight into layer SVGs unmodified.

## Constraints these shapes are drawn to

Verified against Apple's Human Interface Guidelines and three real `.icon`
bundles on this machine (Xcode 27.2):

- macOS layout is square, **1024×1024 px**, layered. Each layer SVG is the
  full canvas; layers register by absolute coordinates.
- The system supplies the rounded-rectangle mask, Liquid Glass material,
  specular highlights, refraction and shadow. Layers must therefore contain
  **no** container shape, bevel, drop shadow, inner glow or background
  gradient — pre-masked layers degrade the system's specular highlights.
- Layers ship **flat and opaque**; transparency is set per group in
  `icon.json`, not painted into the art.
- No feathered edges, hairline strokes or sharp corners — they disintegrate at
  small sizes.
- Six appearances exist (default, dark, clear light/dark, tinted light/dark).
  Only **default and dark** are authored; macOS generates the rest.
- Deliberately no letterforms and no use of the word "Pastry", so the app can
  still be renamed.

## Palette

One foreground palette is shared across appearances; only the background
gradient changes for Dark. That keeps the mark identical in every appearance
(which the HIG asks for) and keeps `icon.json` to a single `dark`
specialization on the background.

| Role | Value |
|---|---|
| Background, default | `#FFD688` → `#E8832B` |
| Background, dark | `#6E4320` → `#23130A` |
| Pastry (light cream) | `#FFF6E4` |
| Pastry (shadowed cream) | `#FBE4BC` |
| Cream filling | `#FFCF86` |
| Blade / steel | `#FFFFFF`, `#E2ECF7` |

## Note on location

`Resources/` currently holds the legacy Objective-C Flycut assets, which a
later step of the rewrite deletes wholesale. This subtree must survive that
deletion — or be moved somewhere unambiguous (`Pastry/Resources/`) when the
icon is wired into the target in feature 10.
