#!/usr/bin/env python3
"""Build Resources/Pastry.icon from the geometry in concepts.py.

The chosen design is the "angled" composition on the rose ground with charcoal
scissors. Everything here is derived, so re-running this after editing
concepts.py regenerates the bundle exactly.

Layout written:

    Resources/Pastry.icon/
      icon.json          manifest: ground fill, groups, layers, all colour
      Assets/*.svg       one full-canvas 1024x1024 white silhouette per layer

Colour convention: the SVGs are pure geometry filled white, and every colour
lives in icon.json. A layer's `fill` in the manifest overrides the fill in its
SVG -- verified against a shipped Icon Composer bundle whose bolt.svg is
`fill="#FFFFFF"` in markup yet renders gold. Keeping colour in one file means a
palette change never touches the artwork.
"""
import json
import os
import pathlib

import concepts

CONCEPT = "angled"
GROUND = "rose"

HERE = pathlib.Path(__file__).resolve().parent
BUNDLE = HERE.parent / "Pastry.icon"


def srgb(hex_colour, alpha=1.0):
    """#RRGGBB -> the "srgb:r,g,b,a" string icon.json uses."""
    h = hex_colour.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return f"srgb:{r:.5f},{g:.5f},{b:.5f},{alpha:.5f}"


def gradient(top, bottom):
    # No "orientation": top-to-bottom is the default, and Icon Composer strips
    # an explicit one on save. Omitting it keeps the file byte-identical across
    # a round trip through the GUI.
    return {"linear-gradient": [srgb(top), srgb(bottom)]}


SVG = ('<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" '
       'viewBox="0 0 1024 1024"><path fill="#FFFFFF" d="{d}"/></svg>\n')

# Scissors are the only thing that changes between appearances. Charcoal on the
# light ground; mid-slate in Dark, because black disappears into the dark ground
# and near-white disappears into the white frosting the blades cross.
SCISSORS = {"default": "#332E3B", "dark": "#A7AFC4"}

# Groups are listed FRONT to BACK, and so are the layers inside them.
# Icon Composer allows 1-4 layers per group, which is why the slice is split.
GROUPS = [
    {
        "name": "Scissors",
        "layers": ["scissors-rings", "scissors-body"],
        "fill": SCISSORS,
        "glass": True,
        "specular": True,
        "shadow": {"kind": "neutral", "opacity": 0.5},
        "translucency": {"enabled": False, "value": 0.5},
    },
    {
        "name": "Garnish",
        "layers": ["cherry", "cherry-stem", "pineapple"],
        "glass": {"cherry": True, "cherry-stem": False, "pineapple": True},
        "specular": True,
        "shadow": {"kind": "neutral", "opacity": 0.5},
        "translucency": {"enabled": False, "value": 0.5},
    },
    {
        "name": "Topping",
        "layers": ["fruit-bits", "frosting"],
        "glass": {"fruit-bits": False, "frosting": True},
        "specular": True,
        "shadow": {"kind": "neutral", "opacity": 0.5},
        "translucency": {"enabled": True, "value": 0.12},
    },
    {
        "name": "Sponge",
        "layers": ["cream", "sponge-top", "sponge-bottom"],
        "glass": True,
        "specular": True,
        "shadow": {"kind": "neutral", "opacity": 0.5},
        "translucency": {"enabled": True, "value": 0.12},
    },
]


def build():
    concept = concepts.by_id(CONCEPT)
    tones = {layer["name"]: layer["light"] for layer in concept["layers"]}
    paths = {layer["name"]: layer["d"] for layer in concept["layers"]}

    assets = BUNDLE / "Assets"
    assets.mkdir(parents=True, exist_ok=True)
    for stale in assets.glob("*.svg"):
        stale.unlink()

    written = []
    for name, d in paths.items():
        (assets / f"{name}.svg").write_text(SVG.format(d=d), encoding="utf-8")
        written.append(f"{name}.svg")

    groups = []
    for spec in GROUPS:
        layers = []
        for name in spec["layers"]:
            if name not in paths:
                raise KeyError(f"group {spec['name']} wants missing layer {name}")
            glass = spec["glass"]
            layer = {
                "image-name": f"{name}.svg",
                "name": name,
                "glass": glass[name] if isinstance(glass, dict) else glass,
            }
            fill = spec.get("fill")
            if isinstance(fill, dict):
                layer["fill-specializations"] = [
                    {"value": {"solid": srgb(fill["default"])}},
                    {"appearance": "dark", "value": {"solid": srgb(fill["dark"])}},
                ]
            else:
                layer["fill"] = {"solid": srgb(tones[name])}
            layers.append(layer)
        groups.append({
            "name": spec["name"],
            "layers": layers,
            "specular": spec["specular"],
            "shadow": spec["shadow"],
            "translucency": spec["translucency"],
        })

    covered = [n for spec in GROUPS for n in spec["layers"]]
    missing = [n for n in paths if n not in covered]
    if missing:
        raise SystemExit(f"layers not placed in any group: {missing}")

    light, dark, _ = concepts.COLORWAYS[GROUND]
    manifest = {
        "fill-specializations": [
            {"value": gradient(*light)},
            {"appearance": "dark", "value": gradient(*dark)},
        ],
        "groups": groups,
        "supported-platforms": {"circles": ["watchOS"], "squares": "shared"},
    }
    # Icon Composer's own formatting: two-space indent, keys sorted, and a
    # space either side of the colon. Matching it means re-saving from the GUI
    # produces no diff, so hand edits there and regeneration here stay legible
    # against each other.
    # No trailing newline, because Icon Composer does not write one. Matching
    # the GUI byte-for-byte matters more here than the usual POSIX habit: the
    # GUI is what gets opened to tune glass and translucency, so it is the tool
    # that will rewrite this file most often.
    (BUNDLE / "icon.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True, separators=(",", " : ")),
        encoding="utf-8")

    rel = os.path.relpath(BUNDLE, HERE.parent.parent)
    print(f"wrote {rel}/icon.json and {len(written)} layers in {rel}/Assets/")
    for group in groups:
        print(f"  {group['name']}: " + ", ".join(l["name"] for l in group["layers"]))


if __name__ == "__main__":
    build()
