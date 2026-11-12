#!/usr/bin/env python3
"""Build Pastry/Pastry.icon from the geometry in cupcake3q.py.

The chosen design is the three-quarter cupcake: three turns of frosting, slate
case with pleats, on the soft rosy ground. Everything here is derived, so
re-running this after editing cupcake3q.py regenerates the bundle exactly.

Layout written:

    Pastry/Pastry.icon/
      icon.json          the ground fill and the layer grouping
      Assets/*.svg       one full-canvas 1024x1024 layer, carrying its own
                         gradient

Colour convention: **each layer SVG carries its own gradient and icon.json sets
no layer fills.** This is the opposite of the previous (flat-colour) icon,
where all colour lived in the manifest, and the reason is that every shape in
this design needs a gradient:

  * A manifest `fill` can only be a solid or the top-level ground gradient; a
    per-layer gradient there is not something any bundle on this machine uses,
    so it is unverified.
  * An SVG gradient is verified to be renderable -- CoreSVG, the framework
    Icon Composer bundles to draw these layers, carries full support for
    linearGradient, stop-color, gradientUnits and objectBoundingBox.
  * Nothing in the cupcake changes between appearances, so no layer needs an
    appearance variant anyway. Only the ground gets a dark specialization.

If a layer ever turns up flat or black in Icon Composer, that is the signal
this assumption broke; the fallback is to flatten that layer to a solid
manifest fill, or export it as a PNG.
"""
import json
import os
import pathlib

import cupcake3q as design

CONCEPT = "tq3"

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parent.parent
BUNDLE = REPO / "Pastry" / "Pastry.icon"


def srgb(hex_colour, alpha=1.0):
    """#RRGGBB -> the "srgb:r,g,b,a" string icon.json uses."""
    h = hex_colour.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return f"srgb:{r:.5f},{g:.5f},{b:.5f},{alpha:.5f}"


def ground(stops):
    # No "orientation": top-to-bottom is the default, and Icon Composer strips
    # an explicit one on save. Omitting it keeps the file byte-identical across
    # a round trip through the GUI.
    return {"linear-gradient": [srgb(stops[0]), srgb(stops[1])]}


def layer_svg(layer):
    """One layer as a full-canvas SVG carrying its own gradient."""
    x1, y1, x2, y2 = layer["dir"]
    c0, c1 = layer["stops"]
    opacity = layer.get("opacity", 1.0)
    fill_opacity = "" if opacity >= 1.0 else f' fill-opacity="{opacity:g}"'
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" '
        'viewBox="0 0 1024 1024">\n'
        f'<defs><linearGradient id="g" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">'
        f'<stop offset="0" stop-color="{c0}"/>'
        f'<stop offset="1" stop-color="{c1}"/></linearGradient></defs>\n'
        f'<path fill="url(#g)"{fill_opacity} d="{layer["d"]}"/>\n'
        '</svg>\n')


# Groups are listed FRONT to BACK, and so are the layers inside them.
# Icon Composer allows 1-4 layers per group.
GROUPS = [
    {"name": "Cherry", "layers": ["cherry-shine", "cherry", "cherry-stem"],
     "glass": True, "specular": True,
     "shadow": {"kind": "neutral", "opacity": 0.5},
     "translucency": {"enabled": False, "value": 0.5}},
    {"name": "Frosting", "layers": ["swirl-0", "swirl-1", "swirl-2"],
     "glass": True, "specular": True,
     "shadow": {"kind": "neutral", "opacity": 0.5},
     "translucency": {"enabled": True, "value": 0.1}},
    {"name": "Case", "layers": ["pleats", "case"],
     "glass": True, "specular": True,
     "shadow": {"kind": "neutral", "opacity": 0.5},
     "translucency": {"enabled": True, "value": 0.1}},
    {"name": "Cake", "layers": ["cake"],
     "glass": True, "specular": True,
     "shadow": {"kind": "neutral", "opacity": 0.5},
     "translucency": {"enabled": False, "value": 0.5}},
]


def build():
    layers = {l["name"]: l for l in design.by_id(CONCEPT)["layers"]}

    assets = BUNDLE / "Assets"
    assets.mkdir(parents=True, exist_ok=True)
    for stale in assets.glob("*.svg"):
        stale.unlink()
    for stale in assets.glob("*.png"):
        stale.unlink()

    for name, layer in layers.items():
        (assets / f"{name}.svg").write_text(layer_svg(layer), encoding="utf-8")

    covered = [n for g in GROUPS for n in g["layers"]]
    missing = [n for n in layers if n not in covered]
    unknown = [n for n in covered if n not in layers]
    if missing:
        raise SystemExit(f"layers not placed in any group: {missing}")
    if unknown:
        raise SystemExit(f"groups reference missing layers: {unknown}")
    too_big = [g["name"] for g in GROUPS if len(g["layers"]) > 4]
    if too_big:
        raise SystemExit(f"groups over the four-layer limit: {too_big}")

    groups = [{
        "name": g["name"],
        "layers": [{"image-name": f"{n}.svg", "name": n, "glass": g["glass"]}
                   for n in g["layers"]],
        "specular": g["specular"],
        "shadow": g["shadow"],
        "translucency": g["translucency"],
    } for g in GROUPS]

    manifest = {
        "fill-specializations": [
            {"value": ground(design.BG["light"])},
            {"appearance": "dark", "value": ground(design.BG["dark"])},
        ],
        "groups": groups,
        "supported-platforms": {"circles": ["watchOS"], "squares": "shared"},
    }

    # Icon Composer's own formatting: two-space indent, keys sorted, a space
    # either side of the colon, and no trailing newline. Matching it means
    # re-saving from the GUI produces no diff.
    (BUNDLE / "icon.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True, separators=(",", " : ")),
        encoding="utf-8")

    rel = os.path.relpath(BUNDLE, REPO)
    print(f"wrote {rel}/icon.json and {len(layers)} layers in {rel}/Assets/")
    for g in groups:
        print(f"  {g['name']}: " + ", ".join(l["name"] for l in g["layers"]))


if __name__ == "__main__":
    build()
