# Pastry app icon — concept sources

Vector sources for the Pastry app bundle icon. This is **not** the menu-bar
glyph (that is a flat monochrome SF Symbol template, a separate asset).

Status: **three compositions, awaiting a decision.** Once one is chosen, the
real `.icon` bundle is produced from the same geometry.

## The design

A simplified side view of a layer-cake slice, taken from a reference photo of a
pineapple-coconut slice: thick frosting cap, sponge, cream with fruit through
it, sponge, and a cherry on top. To its left, a pair of scissors seen from the
side — drawn in the spirit of the classic scissors glyph, but original
geometry, not a trace of it.

Layout: scissors left, garnish right. Light ground, colourful garnish, and the
scissors in a single flat metal or black — no coloured handles.

The scissors are built the way real scissors are, which is what makes them read
as scissors rather than as shears: **each arm is one continuous piece running
from its loop, through the pivot, to the blade on the *opposite* side.** That
crossing is what produces the pinched waist and the open wedge between the
blades. An earlier version hinged two separate blades at a point and read as
surgical shears instead.

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
- `scissors(pivot, deg, scale)` — built along a local +x axis with the loops at
  −x and the blades at +x, then rotated and scaled into place by `xform`.
  Change `deg` to re-angle the whole tool, `scale` to resize it.
- `round_poly`, `taper`, `ring`, `circle` — the primitives those are made of.

Two things in here are easy to get wrong and were both real bugs:

- **`taper`'s end cap must use sweep-flag 0, never 1.** The cap's normal is
  always the left normal of the travel direction, so the sweep is constant; a
  hardcoded `1` makes the cap bite *into* the shape instead of rounding it off.
  Invisible on thin limbs, a gaping crescent on thick ones.
- **Render with the nonzero fill rule, not even-odd.** A scissor arm is a neck
  and a blade that deliberately overlap; under even-odd the overlap cancels to
  a hole. `ring()` winds its inner circle backwards, so nonzero still hollows
  the loops correctly.

`scissors()` returns its rings and its body as **separate paths** for the same
reason: they overlap, and one combined path would cancel itself.

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

The scissors are one flat tone — no separately coloured handles.

The dark-appearance scissors are deliberately mid-slate rather than near-white:
they have to read against the dark ground *and* against the white frosting they
cross. Near-white blades vanish on the frosting, and black vanishes into the
ground. That squeeze is why the default and dark tones are so far apart while
nothing else in the icon changes at all.

Grounds are gradients declared in `icon.json`, not artwork. Four are drawn up
(`COLORWAYS` in `concepts.py`): rose, vanilla, mint, sky.

## Note on location

`Resources/` currently holds the legacy Objective-C Flycut assets, which a
later step of the rewrite deletes wholesale. This subtree must survive that
deletion — or be moved somewhere unambiguous (`Pastry/Resources/`) when the
icon is wired into the target in feature 10.
