# Pastry app icon — concept sources

Vector sources for the Pastry app bundle icon. This is **not** the menu-bar
glyph (that is a flat monochrome SF Symbol template, a separate asset).

Status: **three compositions, awaiting a decision.** Once one is chosen, the
real `.icon` bundle is produced from the same geometry.

## The design

A simplified side view of a layer-cake slice, taken from a reference photo of a
pineapple-coconut slice: thick frosting cap, sponge, cream with fruit through
it, sponge, and a cherry on top. Beside it, a pair of scissors seen from the
side at an angle — drawn in the spirit of the scissors emoji (wide blades,
two handle loops), but original geometry, not a trace of it.

Direction: light ground, colourful garnish, dark scissors for contrast.

## Files

| File | What it is |
|---|---|
| `concepts.py` | The geometry. Emits every composition's layers as SVG path data on stdout as JSON. Single source of truth for the shapes. |
| `contact_sheet.py` | Builds `sheet.svg` from that JSON: each composition at 320 / 128 / 64 / 32 / 16 pt, in both appearances. |
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

## How the shapes are built

Parametric primitives rather than hand-drawn Béziers, so a shape can be
re-proportioned by changing a number instead of dragging control points:

- `cake(x0, x1, ytop, ybot)` — the slice. Band thicknesses are fractions of the
  total height, so the whole slice rescales as one.
- `scissors(pivot, deg, blade_len, arm_len, loop_r, spread)` — built along a
  local +x axis running pivot → handles, blades along −x, then rotated into
  place by `xform`. Change `deg` to re-angle the whole tool.
- `blade_shape` — one blade: wide at the pivot, straight inner cutting edge,
  rounded point. Deliberately chunky; thin blades disappear below 64 pt.
- `round_poly`, `taper`, `ring`, `circle` — the primitives those are made of.

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

**Only the scissors change between appearances.** Everything edible keeps one
palette in both, which is what the HIG asks for (keep the icon's features
consistent across appearances) and keeps `icon.json` down to a single `dark`
specialization on the scissors plus one on the background.

| Role | Default | Dark |
|---|---|---|
| Frosting | `#FFFFFF` | same |
| Sponge | `#F9D89B` | same |
| Cream | `#FFF6E6` | same |
| Pineapple | `#FFC42B` | same |
| Cherry | `#E8384C` | same |
| Stem | `#4E7F3C` | same |
| Scissors | `#332E3B` | `#A7AFC4` |

The dark-appearance scissors are deliberately mid-slate rather than near-white:
they have to read against the dark ground *and* against the white frosting they
cross. Near-white blades vanish on the frosting.

Grounds are gradients declared in `icon.json`, not artwork. Four are drawn up
(`COLORWAYS` in `concepts.py`): rose, vanilla, mint, sky.

## Note on location

`Resources/` currently holds the legacy Objective-C Flycut assets, which a
later step of the rewrite deletes wholesale. This subtree must survive that
deletion — or be moved somewhere unambiguous (`Pastry/Resources/`) when the
icon is wired into the target in feature 10.
