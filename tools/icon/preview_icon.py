#!/usr/bin/env python3
"""Render Pastry/Pastry.icon to a PNG contact sheet.

This reads the BUNDLE -- icon.json and the layer SVGs -- not the generator, so
it doubles as a check that the manifest and the artwork actually agree: layer
names resolve, z-order is what was intended, and every fill parses.

It is an approximation of what macOS will draw. The system supplies the real
rounded-rect mask, Liquid Glass material, specular highlights, refraction and
inter-layer shadows; none of that is simulated here. Use it to check geometry,
colour and small-size legibility, and Icon Composer to judge the material.

    python3 preview_icon.py              # writes pastry-icon.png
    python3 preview_icon.py --svg-only   # writes pastry-icon.svg only
"""
import json
import math
import pathlib
import subprocess
import sys
import xml.etree.ElementTree as ET

HERE = pathlib.Path(__file__).resolve().parent
BUNDLE = HERE.parent.parent / "Pastry" / "Pastry.icon"
SVG_NS = "{http://www.w3.org/2000/svg}"
SIZES = [320, 128, 64, 32, 16]


def to_hex(colour):
    """"srgb:r,g,b,a" or "display-p3:..." -> (#rrggbb, alpha)."""
    if ":" not in colour:
        raise ValueError(f"unrecognised colour {colour!r}")
    _, values = colour.split(":", 1)
    parts = [float(v) for v in values.split(",")]
    r, g, b = parts[:3]
    alpha = parts[3] if len(parts) > 3 else 1.0
    return "#%02X%02X%02X" % tuple(round(c * 255) for c in (r, g, b)), alpha


def pick(spec, appearance):
    """Choose a value out of a `fill-specializations` list."""
    chosen = None
    for entry in spec:
        if entry.get("appearance") is None and chosen is None:
            chosen = entry["value"]
        if entry.get("appearance") == appearance:
            return entry["value"]
    return chosen


def layer_fill(layer, appearance):
    if "fill-specializations" in layer:
        return pick(layer["fill-specializations"], appearance)
    return layer.get("fill")


def read_path(name):
    """Pull the geometry out of a layer SVG, validating it parses."""
    svg = BUNDLE / "Assets" / name
    if not svg.exists():
        raise SystemExit(f"icon.json references a missing layer: {name}")
    root = ET.parse(svg).getroot()
    if root.get("viewBox") != "0 0 1024 1024":
        raise SystemExit(f"{name}: layers must be a full 1024x1024 canvas")
    paths = [el.get("d") for el in root.iter(f"{SVG_NS}path")]
    if not paths:
        raise SystemExit(f"{name}: no <path> found")
    return " ".join(paths)


def squircle(n=5.0, steps=76):
    a = 512.0
    pts = []
    for i in range(steps + 1):
        th = 2 * math.pi * i / steps
        ct, st = math.cos(th), math.sin(th)
        r = a / (abs(ct) ** n + abs(st) ** n) ** (1 / n) if (ct or st) else a
        pts.append((a + r * ct, a + r * st))
    return "M " + " L ".join(f"{x:.1f} {y:.1f}" for x, y in pts) + " Z"


def ground(manifest, appearance, uid):
    value = (pick(manifest["fill-specializations"], appearance)
             if "fill-specializations" in manifest else manifest["fill"])
    if "solid" in value:
        return f'<rect width="1024" height="1024" fill="{to_hex(value["solid"])[0]}"/>', ""
    stops = value["linear-gradient"]
    o = value.get("orientation", {"start": {"x": 0.5, "y": 0}, "stop": {"x": 0.5, "y": 1}})
    grad = (f'<linearGradient id="g{uid}" x1="{o["start"]["x"]}" y1="{o["start"]["y"]}" '
            f'x2="{o["stop"]["x"]}" y2="{o["stop"]["y"]}">'
            + "".join(f'<stop offset="{i}" stop-color="{to_hex(c)[0]}"/>'
                      for i, c in enumerate(stops)) + "</linearGradient>")
    return f'<rect width="1024" height="1024" fill="url(#g{uid})"/>', grad


def compose(manifest, appearance, uid):
    """Groups and layers are listed front to back, so paint them reversed."""
    body = []
    for group in reversed(manifest["groups"]):
        for layer in reversed(group["layers"]):
            if layer.get("hidden"):
                continue
            fill = layer_fill(layer, appearance)
            colour, alpha = to_hex(fill["solid"]) if fill and "solid" in fill else ("#FFFFFF", 1.0)
            d = read_path(layer["image-name"])
            body.append(f'<path d="{d}" fill="{colour}" opacity="{alpha:g}"/>')
    rect, grad = ground(manifest, appearance, uid)
    return rect + "".join(body), grad


def main():
    manifest = json.loads((BUNDLE / "icon.json").read_text())
    mask = squircle()
    defs, body = [], []
    pad, gap, row_h = 20, 26, 352
    width = pad * 2 + 320 + gap + sum(SIZES[1:]) + gap * len(SIZES[1:]) + 120
    height = pad * 2 + 2 * row_h

    uid = 0
    for row, appearance in enumerate(("default", "dark")):
        content, grad = compose(manifest, appearance, row)
        y = pad + row * row_h
        body.append(f'<rect x="0" y="{y - 8}" width="{width}" height="{row_h - 6}" '
                    f'fill="{"#c9c9c9" if row == 0 else "#4a4a4a"}"/>')
        body.append(f'<text x="{pad}" y="{y + 340}" font-family="Helvetica" font-size="15" '
                    f'fill="{"#111" if row == 0 else "#eee"}">Pastry.icon &#8212; {appearance}</text>')
        if grad:
            defs.append(grad)
        x = pad
        for size in SIZES:
            uid += 1
            defs.append(f'<clipPath id="c{uid}"><path d="{mask}"/></clipPath>')
            scale = size / 1024.0
            body.append(f'<g transform="translate({x},{y + (320 - size) / 2}) '
                        f'scale({scale:.6f})" clip-path="url(#c{uid})">{content}</g>')
            x += size + gap

    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
           f'viewBox="0 0 {width} {height}"><defs>{"".join(defs)}</defs>'
           f'<rect width="{width}" height="{height}" fill="#8a8a8a"/>{"".join(body)}</svg>')

    out_svg = HERE / "pastry-icon.svg"
    out_svg.write_text(svg, encoding="utf-8")
    print(f"wrote {out_svg.name}")
    if "--svg-only" in sys.argv:
        return
    try:
        subprocess.run(["rsvg-convert", "-o", str(HERE / "pastry-icon.png"), str(out_svg)],
                       check=True)
        print("wrote pastry-icon.png")
    except (FileNotFoundError, subprocess.CalledProcessError):
        print("rsvg-convert not available; open pastry-icon.svg in a browser instead")


if __name__ == "__main__":
    main()
