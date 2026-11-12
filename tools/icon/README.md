# Pastry app icon

Sources for the Pastry app bundle icon. This is **not** the menu-bar glyph
(that is a flat monochrome SF Symbol template, a separate asset).

The built bundle lives at **`Pastry/Pastry.icon`**, inside the folder the
Xcode project synchronises, which is what gets it compiled into the app.

Status: **shipping design is the cake slice with scissors** (Angled
composition, rose ground, charcoal scissors) — described below and built by
`build_icon.py`.

> **A redesign is under review.** The shipping icon reads as too busy: two
> objects, a diagonal axis, and a lot going on. The replacement drops the
> scissors and reduces the icon to a single cupcake built from a handful of
> shapes — the case, the cream, and one saturated thing on top — everything a
> desaturated pastel with a subtle gradient, on the same rosy ground. The
> cherry is the only saturated colour in the icon.
>
> Two candidate sets, by camera angle:
>
> | Module | Variants | Sheet |
> |---|---|---|
> | `cupcake3q.py` | three-quarter: side on, camera slightly raised | `cupcake3q-concepts.png` |
> | `cupcake.py` | the two strict angles: flat elevation, and overhead | `cupcake-concepts.png` |
>
> Render either with `cupcake_sheet.py [module]` — it defaults to `cupcake3q`.
>
> Nothing in the shipping pipeline points at either yet. When a candidate is
> chosen it replaces `concepts.py` as the source of truth and `build_icon.py`
> is repointed at it; until then `build_icon.py` keeps producing the current
> icon unchanged.

## The shipping design

A simplified side view of a layer-cake slice, taken from a reference photo of a
pineapple-coconut slice: thick frosting cap, sponge, cream with fruit through
it, sponge, and a cherry on top. To its left, a pair of scissors seen from the
side — drawn in the spirit of the classic scissors glyph, but original
geometry, not a trace of it.

Layout: scissors left, garnish right. Light ground, colourful garnish, and the
scissors in a single flat charcoal — no coloured handles.

The scissors are built the way real scissors are, which is what makes them read
as scissors rather than as shears: **each arm is one continuous piece running
from its loop, through the pivot, to the blade on the *opposite* side.** That
crossing is what produces the pinched waist and the open wedge between the
blades. An earlier version hinged two separate blades at a point and read as
surgical shears.

Deliberately no letterforms and no use of the word "Pastry", so the app can
still be renamed without touching the artwork.

## Files

| File | What it is |
|---|---|
| `concepts.py` | The geometry. Every composition's layers as SVG path data. Single source of truth for the shapes; importable (`concepts.by_id("angled")`) or run it to dump JSON. |
| `build_icon.py` | Builds `Pastry/Pastry.icon` from that geometry. Owns the grouping, the colours and the appearance variants. |
| `preview_icon.py` | Renders the **built bundle** to a PNG contact sheet. Reads `icon.json` and the layer SVGs, so it also checks that the manifest and the artwork agree. |
| `contact_sheet.py` | Renders all the *candidate* compositions side by side — the decision aid, kept for when the design is revisited. |
| `concepts.png` | The candidate contact sheet, checked in so it is reviewable without running anything. |
| `pastry-icon.png` | The chosen icon, rendered from the bundle, both appearances, 320 → 16 pt. |

## Rebuilding

```sh
cd tools/icon
python3 build_icon.py       # regenerates Pastry/Pastry.icon
python3 preview_icon.py     # re-renders pastry-icon.png from the bundle
```

Stdlib Python 3 only, except `rsvg-convert` (librsvg) for the PNG step; pass
`--svg-only` to skip it, or open the emitted `.svg` in any browser.

To change the design, edit `concepts.py` and re-run both. To change only
colour, grouping or appearance variants, edit `build_icon.py` — the artwork
does not need to be touched (see the colour convention below).

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
reason: they overlap, and one combined path would cancel itself. They stay
separate layers in the bundle.

## The bundle

```
Pastry/Pastry.icon/
  icon.json          ground fill, groups, layers, and all colour
  Assets/*.svg       one full-canvas 1024x1024 white silhouette per layer
```

**Colour convention: the SVGs are pure geometry filled white, and every colour
lives in `icon.json`.** A layer's `fill` in the manifest overrides the fill in
its SVG — verified against a shipped Icon Composer bundle whose `bolt.svg` is
`fill="#FFFFFF"` in markup yet renders gold. Keeping colour in one file means a
palette change never touches the artwork, and a layer that renders white in
Icon Composer is a loud, obvious signal that its fill failed to apply.

Groups are listed **front to back**, and so are the layers inside them. Icon
Composer allows 1–4 layers per group, which is why the slice is split across
two groups rather than one:

| Group | Layers |
|---|---|
| Scissors | `scissors-rings`, `scissors-body` |
| Garnish | `cherry`, `cherry-stem`, `pineapple` |
| Topping | `fruit-bits`, `frosting` |
| Sponge | `cream`, `sponge-top`, `sponge-bottom` |

## Palette

**Only the scissors change between appearances.** Everything edible keeps one
palette in both, which is what the HIG asks for (keep the icon's features
consistent across appearances) and keeps `icon.json` down to a single `dark`
specialization on the scissors plus one on the ground.

| Role | Default | Dark |
|---|---|---|
| Ground (gradient) | `#FFF0EB` → `#FFC6CE` | `#5C3039` → `#2A1419` |
| Frosting | `#FFFFFF` | same |
| Sponge | `#F9D89B` | same |
| Cream | `#FFF6E6` | same |
| Pineapple | `#FFC42B` | same |
| Cherry | `#E8384C` | same |
| Stem | `#4E7F3C` | same |
| Scissors | `#332E3B` | `#A7AFC4` |

The dark-appearance scissors are deliberately mid-slate rather than near-white:
they have to read against the dark ground *and* against the white frosting they
cross. Near-white blades vanish on the frosting, and black vanishes into the
ground. That squeeze is why the default and dark tones are so far apart while
nothing else in the icon changes at all.

Three other grounds are drawn up in `concepts.py` (`COLORWAYS`: vanilla, mint,
sky) if the rose is ever reconsidered — change `GROUND` in `build_icon.py`.

## Constraints the artwork is drawn to

Verified against Apple's Human Interface Guidelines and three real `.icon`
bundles on this machine (Xcode 27.2):

- macOS layout is square, **1024×1024 px**, layered. Each layer SVG is the
  full canvas; layers register by absolute coordinates.
- The system supplies the rounded-rectangle mask, Liquid Glass material,
  specular highlights, refraction and shadow. Layers therefore contain **no**
  container shape, bevel, drop shadow, inner glow or background gradient —
  pre-masked layers degrade the system's specular highlights.
- Layers are **flat and opaque**; transparency is set per group in `icon.json`
  (`translucency`), not painted into the art.
- No feathered edges, hairline strokes or sharp corners — they disintegrate at
  small sizes.
- Six appearances exist (default, dark, clear light/dark, tinted light/dark).
  Only **default and dark** are authored; macOS generates the rest.

## What is verified

- `icon.json` is valid JSON; every `image-name` resolves to a file, with no
  orphan assets, and no group exceeds the four-layer limit.
- Every layer SVG parses as XML and is a full `0 0 1024 1024` canvas.
- The bundle composites correctly **from its own files** — `preview_icon.py`
  reads the manifest and the SVGs, not the generator.
- macOS identifies it as `com.apple.iconcomposer.icon`
  (`mdls -name kMDItemContentType Pastry/Pastry.icon`), the same content
  type as a GUI-authored bundle.
- **It opens in Icon Composer and renders correctly** — all four groups and
  ten layers appear with the right names and nesting, every fill applies, and
  the Liquid Glass render looks right.
- **It round-trips through the GUI byte-identically.** Saving from Icon
  Composer and re-running `build_icon.py` produce the same file. This is why
  `build_icon.py` writes Icon Composer's exact JSON style (two-space indent,
  sorted keys, a space either side of the colon, no trailing newline) and
  omits the gradient `orientation` — Icon Composer strips an explicit
  top-to-bottom orientation because that is already the default.

The one thing a GUI save adds that the generator does not is `"hidden": false`
on a layer whose visibility was toggled. It is a redundant default and
regenerating drops it again; harmless either way.

## Still worth a human eye

The `glass` flags and the `translucency` values (0.12 on Topping and Sponge,
off elsewhere) are a conservative first pass chosen to be predictable, not
tuned. So are the specular settings. If they want adjusting, change them in
`build_icon.py` rather than the GUI, or change them in the GUI and port the
numbers back — otherwise the next `build_icon.py` run overwrites them.

The system-generated **clear** and **tinted** appearances have not been looked
at closely. The thing to check is that the scissors survive, since they are the
only element carrying a dark specialization.

Icon Composer is GUI-only — it ships inside Xcode at
`Xcode.app/Contents/Applications/Icon Composer.app` and there is no
command-line equivalent (`xcrun --find icon-composer` fails). It is not needed
to build or ship the app; Xcode compiles the bundle as it is.

## Note on location

This folder lives in `tools/` because it is tooling: it *builds* an input to
the app rather than documenting one. The bundle it writes, `Pastry/Pastry.icon`,
has to sit inside the folder the Xcode project synchronises, which is what
gets actool to compile it into the app.

It used to live in `Resources/` beside the legacy Flycut artwork. That whole
folder was deleted in feature 10; this moved out first, because without the
generator and these vector sources the icon bundle would be a binary nobody
could regenerate.
