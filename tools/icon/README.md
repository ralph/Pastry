# Pastry app icon

Sources for the Pastry app bundle icon. This is **not** the menu-bar glyph
(that is a flat monochrome SF Symbol template, a separate asset).

The built bundle lives at **`Pastry/Pastry.icon`**, inside the folder the Xcode
project synchronises, which is what gets it compiled into the app.

Status: **three-quarter cupcake, three turns, soft rosy ground, slate case.**
Built by `build_icon.py` from `cupcake3q.py`.

## The design

A cupcake seen from the side with the camera slightly raised — a three-quarter
view, between a flat elevation and a pure overhead. Four things and nothing
else: the paper case, a sliver of cake, three turns of piped frosting, and a
cherry.

Raising the camera is a geometry change, not a styling one, and it is what
makes the thing read as a cupcake rather than a stack of shapes:

- the case rim becomes an **ellipse**, so the case's top edge is the *front*
  half of that ellipse and dips lowest at the centre;
- the pleats run from the rim to the base along lines of constant angle, which
  **compresses them towards both edges on its own** — a vertical at angle `t`
  projects to `cx + rx·cos(t)`, so the foreshortening is free;
- every turn of the swirl is an ellipse rather than a flat band.

Proportions follow the way a real cupcake sits: **cake widest** (the muffin
top), case rim a little narrower, swirl narrower still.

Everything is a desaturated pastel with a subtle gradient. **The cherry is the
only saturated colour in the icon**, which is what makes it read instantly at
any size. Deliberately no letterforms and no use of the word "Pastry", so the
app can still be renamed without touching the artwork.

## Files

| File | What it is |
|---|---|
| `cupcake3q.py` | The geometry and the palette. Single source of truth for the shapes; importable (`by_id("tq3")`) or run it to dump JSON. |
| `build_icon.py` | Builds `Pastry/Pastry.icon` from that geometry. Owns the layer grouping and the ground. |
| `preview_icon.py` | Renders the **built bundle** to a PNG contact sheet. Reads `icon.json` and the layer SVGs, so it also checks that the manifest and the artwork agree. |
| `export_png.py` | Exports the bundle as web-ready PNGs — masked, shadowed, transparent. Refreshes `site/assets/`. |
| `cupcake_sheet.py` | Renders a candidate *set* side by side — the decision aid, for exploring alternatives. |
| `cupcake3q-concepts.png` | The turn-count comparison (five / four / three), checked in. |
| `pastry-icon.png` | The shipping icon, rendered from the bundle, both appearances, 320 → 16 pt. |

## Rebuilding

```sh
cd tools/icon
python3 build_icon.py       # regenerates Pastry/Pastry.icon
python3 preview_icon.py     # re-renders pastry-icon.png from the bundle
python3 export_png.py       # refreshes site/assets/pastry-{256,512}.png
```

Stdlib Python 3 only, except `rsvg-convert` (librsvg) for the PNG steps; pass
`--svg-only` to skip it in `preview_icon.py`, or open the emitted `.svg` in any
browser.

## Where the icon is used

- **The app.** `Pastry/Pastry.icon` is inside the folder the Xcode project
  synchronises, and the target sets `ASSETCATALOG_COMPILER_APPICON_NAME =
  Pastry`. There is no asset catalog, so replacing the bundle in place is all
  the app needs — no project edit. App Store Connect takes a Mac app's icon
  from the build, so there is no 1024 PNG to upload either.
- **The website.** `site/assets/pastry-256.png` (favicon, header, hero) and
  `pastry-512.png` (`og:image`). Regenerate both with `export_png.py` after any
  change to the icon, or the site keeps serving the old one. The hero's `alt`
  text in `site/index.html` describes the icon, so it needs updating too when
  the design changes.

The **menu-bar glyph is a different asset** and is not produced here: it is the
`scissors` SF Symbol, set in `Pastry/MenuBarIcon.swift`, because macOS requires
menu bar items to be flat monochrome templates. Every "scissors" in the README,
the site and the App Store copy refers to that, not to this icon.

## How the shapes are built

Parametric primitives rather than hand-drawn Béziers, so a shape can be
re-proportioned by changing a number instead of dragging control points.

`swirl_turns(n)` interpolates the turns between a **fixed** bottom and top
ellipse. That means the swirl's height and taper stay put however many turns
there are — changing `n` only makes the banding coarser or finer, never the
silhouette, and the cherry keeps sitting correctly on the tip. The small
off-centre nudge that reads as a spiral **fades out towards the tip**, so the
top turn stays centred under the cherry; a constant nudge looks like a spiral
at five turns but merely lopsided at three.

Two things here are easy to get wrong and were both real bugs:

- **The cake is a full ellipse, not a half-dome.** A half-dome ends in two
  sharp corners at its flat bottom, and those corners stick out past the case
  as spurs. A full ellipse curves back under, so the overhang reads as a muffin
  top and the rest hides behind the case. The cake also has to run down *past*
  the lowest point of the case's front rim, or a gap opens between them.
- **Render with the nonzero fill rule, not even-odd.** Shapes here overlap on
  purpose; under even-odd an overlap cancels to a hole.

## The bundle

```
Pastry/Pastry.icon/
  icon.json          the ground fill and the layer grouping
  Assets/*.svg       one full-canvas 1024x1024 layer, carrying its own gradient
```

**Colour convention: each layer SVG carries its own gradient, and `icon.json`
sets no layer fills.** This is the *opposite* of the previous flat-colour icon,
where all colour lived in the manifest. The reason is that every shape in this
design needs a gradient:

- a manifest `fill` can only be a solid, or the top-level ground gradient; a
  per-layer gradient there is not something any `.icon` bundle on this machine
  uses, so it is unverified;
- an SVG gradient *is* verified to be renderable — CoreSVG, the framework Icon
  Composer bundles to draw these layers, carries full support for
  `linearGradient`, `stop-color`, `gradientUnits` and `objectBoundingBox`;
- nothing in the cupcake changes between appearances, so no layer needs an
  appearance variant anyway. Only the ground gets a `dark` specialization.

If a layer ever turns up flat or black in Icon Composer, that is the signal
this assumption broke. The fallback is to flatten that layer to a solid
manifest fill, or export it as a PNG.

Groups are listed **front to back**, and so are the layers inside them. Icon
Composer allows 1–4 layers per group:

| Group | Layers |
|---|---|
| Cherry | `cherry-shine`, `cherry`, `cherry-stem` |
| Frosting | `swirl-0`, `swirl-1`, `swirl-2` |
| Case | `pleats`, `case` |
| Cake | `cake` |

## Palette

| Role | Colour |
|---|---|
| Ground, default | `#FFF3EF` → `#FFC8D2` |
| Ground, dark | `#5E323B` → `#2B151A` |
| Case | `#CBD9E0` → `#9FB4C0` |
| Pleats | `#B9CAD3` → `#8EA5B2` |
| Cake | `#EFDFC2` → `#D3B88F` |
| Cream | `#FFFCF6` → `#E4D3C0` |
| Cherry | `#F2566B` → `#C8102E` |
| Stem | `#A8906F` → `#7E674B` |

Four more case colours are drawn up in `cupcake3q.py` (`CASES`: sage, lilac,
sand, rose) if slate is ever reconsidered.

**Nothing changes between appearances except the ground.** Every shape is pale
enough to read on both, which keeps the icon's features identical across all
six appearances — what the guidelines ask for — and keeps the manifest about as
simple as it can be.

## What is verified

- `icon.json` is valid JSON; every `image-name` resolves with no orphan assets;
  no group exceeds the four-layer limit; the ground carries both appearances.
- Every layer SVG parses as XML and is a full `0 0 1024 1024` canvas.
- The bundle composites correctly **from its own files** — `preview_icon.py`
  reads the manifest and the SVGs, not the generator.
- macOS identifies it as `com.apple.iconcomposer.icon`
  (`mdls -name kMDItemContentType Pastry/Pastry.icon`), the same content type
  as a GUI-authored bundle.
- `build_icon.py` writes Icon Composer's exact JSON style (two-space indent,
  sorted keys, a space either side of the colon, no trailing newline), so
  saving from the GUI and regenerating from source produce the same file.

## Still worth a human eye

- **That the SVG gradients render in Icon Composer.** CoreSVG supports them and
  the bundle previews correctly here, but it has not been opened in the GUI
  since the design changed. This is the one new assumption.
- The `glass` flags and the `translucency` values (0.1 on Frosting and Case,
  off elsewhere) are a conservative first pass chosen to be predictable, not
  tuned. Change them in `build_icon.py` rather than the GUI, or change them in
  the GUI and port the numbers back — otherwise the next build overwrites them.
- The system-generated **clear** and **tinted** appearances.

Icon Composer is GUI-only — it ships inside Xcode at
`Xcode.app/Contents/Applications/Icon Composer.app` and there is no
command-line equivalent (`xcrun --find icon-composer` fails). It is not needed
to build or ship the app; Xcode compiles the bundle as it is.

## History

The icon before this one was a slice of layer cake with a pair of scissors,
which read as too busy: two objects, a diagonal axis, and a lot going on. Its
generator (`concepts.py`) and the intermediate straight-on cupcake candidates
(`cupcake.py`) were removed when this design landed; both are in git history.
