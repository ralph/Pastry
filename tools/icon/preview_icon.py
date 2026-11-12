#!/usr/bin/env python3
"""Render Pastry/Pastry.icon to a PNG contact sheet.

This reads the BUNDLE -- icon.json and the layer SVGs -- not the generator, so
it doubles as a check that the manifest and the artwork agree: layer names
resolve, z-order is what was intended, and every layer parses and carries the
fill it should.

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
SVG_NS = "http://www.w3.org/2000/svg"
Q = f"{{{SVG_NS}}}"
SIZES = [320, 128, 64, 32, 16]

ET.register_namespace("", SVG_NS)


def to_hex(colour):
    """"srgb:r,g,b,a" or "display-p3:..." -> (#rrggbb, alpha)."""
    if ":" not in colour:
        raise ValueError(f"unrecognised colour {colour!r}")
    parts = [float(v) for v in colour.split(":", 1)[1].split(",")]
    return ("#%02X%02X%02X" % tuple(round(c * 255) for c in parts[:3]),
            parts[3] if len(parts) > 3 else 1.0)


def pick(spec, appearance):
    """Choose a value out of a `fill-specializations` list."""
    chosen = None
    for entry in spec:
        if entry.get("appearance") is None and chosen is None:
            chosen = entry["value"]
        if entry.get("appearance") == appearance:
            return entry["value"]
    return chosen


def read_layer(name, tag):
    """Inline one layer SVG, namespacing its gradient ids so several layers can
    share one document. Returns (defs_markup, body_markup)."""
    svg = BUNDLE / "Assets" / name
    if not svg.exists():
        raise SystemExit(f"icon.json references a missing layer: {name}")
    root = ET.parse(svg).getroot()
    if root.get("viewBox") != "0 0 1024 1024":
        raise SystemExit(f"{name}: layers must be a full 1024x1024 canvas")

    rename = {}
    for defs in root.findall(f"{Q}defs"):
        for el in list(defs):
            old = el.get("id")
            if old:
                rename[old] = f"{tag}-{old}"
                el.set("id", rename[old])

    def remap(el):
        for attr in ("fill", "stroke"):
            v = el.get(attr)
            if v and v.startswith("url(#"):
                ref = v[5:-1]
                if ref in rename:
                    el.set(attr, f"url(#{rename[ref]})")
        for child in el:
            remap(child)

    remap(root)

    defs_markup = "".join(
        ET.tostring(el, encoding="unicode")
        for defs in root.findall(f"{Q}defs") for el in defs)
    body = [el for el in root if not el.tag.endswith("defs")]
    if not body:
        raise SystemExit(f"{name}: nothing to draw")
    return defs_markup, "".join(ET.tostring(el, encoding="unicode") for el in body)


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
    o = value.get("orientation",
                  {"start": {"x": 0.5, "y": 0}, "stop": {"x": 0.5, "y": 1}})
    grad = (f'<linearGradient id="bg{uid}" x1="{o["start"]["x"]}" y1="{o["start"]["y"]}" '
            f'x2="{o["stop"]["x"]}" y2="{o["stop"]["y"]}">'
            + "".join(f'<stop offset="{i}" stop-color="{to_hex(c)[0]}"/>'
                      for i, c in enumerate(stops)) + "</linearGradient>")
    return f'<rect width="1024" height="1024" fill="url(#bg{uid})"/>', grad


def compose(manifest, appearance, uid):
    """Groups and layers are listed front to back, so paint them reversed."""
    defs, body = [], []
    for gi, group in enumerate(reversed(manifest["groups"])):
        for li, layer in enumerate(reversed(group["layers"])):
            if layer.get("hidden"):
                continue
            d, b = read_layer(layer["image-name"], f"u{uid}g{gi}l{li}")
            defs.append(d)
            # A manifest fill, if present, overrides whatever the SVG carries.
            fill = layer.get("fill")
            if fill and "solid" in fill:
                colour, alpha = to_hex(fill["solid"])
                b = f'<g fill="{colour}" opacity="{alpha:g}">{b}</g>'
            body.append(b)
    rect, grad = ground(manifest, appearance, uid)
    return "".join(defs) + grad, rect + "".join(body)


def main():
    manifest = json.loads((BUNDLE / "icon.json").read_text())
    mask = squircle()
    defs, body = [], []
    pad, gap, row_h = 20, 26, 352
    width = pad * 2 + 320 + gap + sum(SIZES[1:]) + gap * len(SIZES[1:]) + 120
    height = pad * 2 + 2 * row_h

    for row, appearance in enumerate(("default", "dark")):
        d, content = compose(manifest, appearance, row)
        defs.append(d)
        y = pad + row * row_h
        body.append(f'<rect x="0" y="{y - 8}" width="{width}" height="{row_h - 6}" '
                    f'fill="{"#c9c9c9" if row == 0 else "#4a4a4a"}"/>')
        body.append(f'<text x="{pad}" y="{y + 340}" font-family="Helvetica" font-size="15" '
                    f'fill="{"#111" if row == 0 else "#eee"}">'
                    f'Pastry.icon &#8212; {appearance}</text>')
        x = pad
        for i, size in enumerate(SIZES):
            cid = f"c{row}{i}"
            defs.append(f'<clipPath id="{cid}"><path d="{mask}"/></clipPath>')
            body.append(f'<g transform="translate({x},{y + (320 - size) / 2}) '
                        f'scale({size / 1024.0:.6f})" clip-path="url(#{cid})">'
                        f'{content}</g>')
            x += size + gap

    svg = (f'<svg xmlns="{SVG_NS}" width="{width}" height="{height}" '
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
