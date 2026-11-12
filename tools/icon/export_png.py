#!/usr/bin/env python3
"""Export Pastry/Pastry.icon as web-ready PNGs.

These are the icon as a *picture* rather than as layers, so unlike the bundle
they carry the two things the system would otherwise add: the rounded-rect
mask, and a soft drop shadow. Transparent background, icon inset to leave room
for the shadow.

Reads the built bundle (via preview_icon's helpers), so what gets exported is
whatever is actually in Pastry.icon.

    python3 export_png.py                  # refresh site/assets at 256 and 512
    python3 export_png.py 1024 out.png     # one arbitrary size
    python3 export_png.py --dark 512 d.png # the dark appearance

Needs rsvg-convert (librsvg).
"""
import json
import pathlib
import subprocess
import sys

import preview_icon as pv

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parent.parent
SITE_ASSETS = REPO / "site" / "assets"

# All in the 1024 canvas. The icon is inset so the shadow has somewhere to go.
INSET = 72
SHADOW_DY = 16
SHADOW_BLUR = 20
SHADOW_OPACITY = 0.22


def build_svg(appearance="default"):
    manifest = json.loads((pv.BUNDLE / "icon.json").read_text())
    defs, content = pv.compose(manifest, appearance, 0)
    scale = (1024 - 2 * INSET) / 1024
    return (
        f'<svg xmlns="{pv.SVG_NS}" width="1024" height="1024" '
        f'viewBox="0 0 1024 1024">'
        f'<defs>{defs}'
        f'<clipPath id="mask" clipPathUnits="userSpaceOnUse">'
        f'<path d="{pv.squircle()}"/></clipPath>'
        f'<filter id="shadow" x="-25%" y="-25%" width="150%" height="150%">'
        f'<feDropShadow dx="0" dy="{SHADOW_DY}" stdDeviation="{SHADOW_BLUR}" '
        f'flood-color="#000000" flood-opacity="{SHADOW_OPACITY}"/>'
        f'</filter></defs>'
        f'<g filter="url(#shadow)">'
        f'<g transform="translate({INSET},{INSET}) scale({scale:.6f})" '
        f'clip-path="url(#mask)">{content}</g></g></svg>')


def render(svg, out, size):
    tmp = HERE / ".export.svg"
    tmp.write_text(svg, encoding="utf-8")
    try:
        subprocess.run(["rsvg-convert", "-w", str(size), "-h", str(size),
                        "-o", str(out), str(tmp)], check=True)
    finally:
        tmp.unlink(missing_ok=True)
    print(f"wrote {out.relative_to(REPO)} ({size}x{size})")


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    appearance = "dark" if "--dark" in sys.argv else "default"
    svg = build_svg(appearance)

    if len(args) == 2:
        render(svg, pathlib.Path(args[1]).resolve(), int(args[0]))
        return

    if not SITE_ASSETS.is_dir():
        raise SystemExit(f"no {SITE_ASSETS.relative_to(REPO)} to write into")
    for size in (256, 512):
        render(svg, SITE_ASSETS / f"pastry-{size}.png", size)


if __name__ == "__main__":
    main()
