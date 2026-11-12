#!/usr/bin/env python3
"""Contact sheet for a cupcake candidate set: every variant, both appearances,
320 -> 16 pt.

    python3 cupcake_sheet.py              # cupcake3q (the three-quarter set)
    python3 cupcake_sheet.py cupcake      # the straight-on set
    python3 cupcake_sheet.py <mod> --svg-only

Any module exposing emit() -> {squircle, bg, concepts} works. Unlike
contact_sheet.py (which renders the older flat-fill scissors concepts) this one
understands per-shape gradients, because every shape in the cupcake designs
carries one.
"""
import html
import importlib
import pathlib
import subprocess
import sys

HERE = pathlib.Path(__file__).resolve().parent
SIZES = [320, 128, 64, 32, 16]
PAD, GAP, ROWH = 20, 26, 352

args = [a for a in sys.argv[1:] if not a.startswith("-")]
module = args[0] if args else "cupcake3q"
d = importlib.import_module(module).emit()

defs, body = [], []
uid = [0]


def grad(stops, direction):
    uid[0] += 1
    gid = f"g{uid[0]}"
    x1, y1, x2, y2 = direction
    defs.append(
        f'<linearGradient id="{gid}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">'
        f'<stop offset="0" stop-color="{stops[0]}"/>'
        f'<stop offset="1" stop-color="{stops[1]}"/></linearGradient>')
    return gid


def tile(c, mode, size, x, y):
    uid[0] += 1
    cid = f"c{uid[0]}"
    defs.append(f'<clipPath id="{cid}"><path d="{d["squircle"]}"/></clipPath>')
    bg = grad(d["bg"][mode], (0, 0, 0, 1))
    # Layers are listed front to back, so paint them reversed.
    layers = "".join(
        f'<path d="{l["d"]}" fill="url(#{grad(l["stops"], l["dir"])})" '
        f'opacity="{l.get("opacity", 1.0):g}"/>'
        for l in reversed(c["layers"]))
    s = size / 1024.0
    return (f'<g transform="translate({x:.2f},{y:.2f}) scale({s:.6f})" '
            f'clip-path="url(#{cid})">'
            f'<rect width="1024" height="1024" fill="url(#{bg})"/>{layers}</g>')


W = PAD * 2 + 320 + GAP + sum(SIZES[1:]) + GAP * len(SIZES[1:]) + 120
H = PAD * 2 + len(d["concepts"]) * 2 * ROWH

for ci, c in enumerate(d["concepts"]):
    for mi, mode in enumerate(("light", "dark")):
        ry = PAD + (ci * 2 + mi) * ROWH
        body.append(f'<rect x="0" y="{ry - 8}" width="{W}" height="{ROWH - 6}" '
                    f'fill="{"#c9c9c9" if mi == 0 else "#4a4a4a"}"/>')
        body.append(
            f'<text x="{PAD}" y="{ry + 340}" font-family="Helvetica" font-size="15" '
            f'fill="{"#111" if mi == 0 else "#eee"}">'
            f'{html.escape(c["title"])} &#8212; {mode}</text>')
        x = PAD
        for s in SIZES:
            body.append(tile(c, mode, s, x, ry + (320 - s) / 2))
            x += s + GAP

svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
       f'viewBox="0 0 {W} {H}"><defs>{"".join(defs)}</defs>'
       f'<rect width="{W}" height="{H}" fill="#8a8a8a"/>{"".join(body)}</svg>')

out_svg = HERE / f"{module}-concepts.svg"
out_svg.write_text(svg, encoding="utf-8")
print(f"wrote {out_svg.name} ({W}x{H})")

if "--svg-only" not in sys.argv:
    try:
        subprocess.run(
            ["rsvg-convert", "-o", str(HERE / f"{module}-concepts.png"), str(out_svg)],
            check=True)
        print(f"wrote {module}-concepts.png")
    except (FileNotFoundError, subprocess.CalledProcessError):
        print("rsvg-convert not available; open the .svg in a browser instead")
