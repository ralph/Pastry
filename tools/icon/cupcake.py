"""Pastry app icon, round 4: a round, symmetric, minimal cupcake.

No scissors. Three elements -- the case, the cream, and one saturated thing on
top. Everything pastel with a subtle gradient in every shape, on the rosy
ground. Canvas 1024x1024, y-down.
"""
import json
import math

C = 1024.0
MID = 512.0


def P(x, y):
    return f"{x:.1f} {y:.1f}".replace(".0", "")


def round_poly(pts, radii):
    """Polygon with per-vertex rounded corners. The sweep is taken per corner
    from the cross product, so concave corners round correctly too."""
    n = len(pts)
    if isinstance(radii, (int, float)):
        radii = [radii] * n
    corners = []
    for i in range(n):
        v = pts[i]; pv = pts[i - 1]; nx_ = pts[(i + 1) % n]
        d1 = (pv[0] - v[0], pv[1] - v[1]); d2 = (nx_[0] - v[0], nx_[1] - v[1])
        l1 = math.hypot(*d1) or 1e-9; l2 = math.hypot(*d2) or 1e-9
        u1 = (d1[0] / l1, d1[1] / l1); u2 = (d2[0] / l2, d2[1] / l2)
        dot = max(-1.0, min(1.0, u1[0] * u2[0] + u1[1] * u2[1]))
        theta = math.acos(dot)
        if theta < 1e-6 or abs(theta - math.pi) < 1e-6:
            corners.append((v, v, 0.0, 1))
            continue
        t = min(radii[i] / math.tan(theta / 2), l1 / 2, l2 / 2)
        cross = u1[0] * u2[1] - u1[1] * u2[0]
        corners.append(((v[0] + u1[0] * t, v[1] + u1[1] * t),
                        (v[0] + u2[0] * t, v[1] + u2[1] * t),
                        t * math.tan(theta / 2), 1 if cross < 0 else 0))
    d = "M " + P(*corners[0][0])
    for a, b, r, sw in corners:
        d += " L " + P(*a)
        d += (f" A {r:.1f} {r:.1f} 0 0 {sw} {P(*b)}" if r > 0.01 else " L " + P(*b))
    return d + " Z"


def circle(cx, cy, r):
    return (f"M {P(cx - r, cy)} A {r:.1f} {r:.1f} 0 0 1 {P(cx + r, cy)} "
            f"A {r:.1f} {r:.1f} 0 0 1 {P(cx - r, cy)} Z")


def ellipse(cx, cy, rx, ry):
    return (f"M {P(cx - rx, cy)} A {rx:.1f} {ry:.1f} 0 0 1 {P(cx + rx, cy)} "
            f"A {rx:.1f} {ry:.1f} 0 0 1 {P(cx - rx, cy)} Z")


def dome(cx, cy, rx, ry):
    """Upper half of an ellipse, flat along y = cy."""
    return f"M {P(cx - rx, cy)} A {rx:.1f} {ry:.1f} 0 0 1 {P(cx + rx, cy)} Z"


def pill(cx, cy, w, h):
    """Horizontal pill (rounded rect, radius h/2) centred on (cx, cy)."""
    x0, x1 = cx - w / 2, cx + w / 2
    y0, y1 = cy - h / 2, cy + h / 2
    return round_poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], h / 2)


def scalloped(cx, cy, r_in, lobes, depth):
    """A circle with a scalloped edge -- a paper case seen from above.

    Built from one circular arc per lobe rather than a sampled polyline: the
    chord between two valleys plus the bulge height determines the arc radius
    exactly, so it is both smooth and compact.
    """
    chord = 2 * r_in * math.sin(math.pi / lobes)
    r_lobe = (chord ** 2 / 4 + depth ** 2) / (2 * depth)
    pts = [(cx + r_in * math.cos(2 * math.pi * i / lobes),
            cy + r_in * math.sin(2 * math.pi * i / lobes))
           for i in range(lobes)]
    d = "M " + P(*pts[0])
    for i in range(1, lobes + 1):
        d += f" A {r_lobe:.1f} {r_lobe:.1f} 0 0 1 {P(*pts[i % lobes])}"
    return d + " Z"


def liner(cy_top, cy_bot, half_top, half_bot, r_top=14, r_bot=34):
    """The cupcake case: a symmetric trapezoid, wider at the top."""
    return round_poly([(MID - half_top, cy_top), (MID + half_top, cy_top),
                       (MID + half_bot, cy_bot), (MID - half_bot, cy_bot)],
                      [r_top, r_top, r_bot, r_bot])


# ------------------------------------------------------------------ palette
# Pastel everywhere, with a subtle gradient in every shape. The cherry is the
# only saturated thing in the icon -- it is what the eye should land on.
# Each entry is ((top colour, bottom colour), (x1, y1, x2, y2)) in the shape's
# own bounding box, so a gradient always spans the shape it fills.
G = {
    "liner":    (("#B6E3D1", "#7CC0A6"), (0, 0, 0, 1)),
    "frosting": (("#FFFDF8", "#F7E3D1"), (0, 0, 0, 1)),
    "plate":    (("#FFFFFF", "#E4D8D6"), (0, 0, 0, 1)),
    "cherry":   (("#F7596E", "#D2203D"), (0.3, 0, 0.75, 1)),
}

BG = {"light": ("#FFE9EA", "#FFBCC9"), "dark": ("#5E323B", "#2B151A")}

# Alternative case colours, for the colourway comparison.
LINERS = {
    "mint":   ("#B6E3D1", "#7CC0A6"),
    "lilac":  ("#E8E0F7", "#C0AEE8"),
    "butter": ("#FFF0CC", "#F5D98F"),
    "sky":    ("#DEEDFB", "#AFCFF0"),
    "blush":  ("#FFE4E8", "#F3BCC6"),
}


def L(name, d, tone):
    stops, direction = G[tone]
    return {"name": name, "d": d, "tone": tone,
            "stops": list(stops), "dir": list(direction)}


CONCEPTS = []

# Layers are listed FRONT to BACK, matching icon.json's convention.

# ================================================================== A. Dome
CONCEPTS.append({
    "id": "dome", "title": "Dome",
    "line": "The most minimal reading: one swept dome of cream on the case, cherry centred.",
    "layers": [
        L("cherry", circle(MID, 272, 54), "cherry"),
        L("frosting", dome(MID, 586, 244, 272), "frosting"),
        L("liner", liner(584, 812, 216, 160), "liner"),
    ]})

# ================================================================= B. Swirl
CONCEPTS.append({
    "id": "swirl", "title": "Swirl",
    "line": "Three soft tiers instead of one dome — more cupcake, still symmetric.",
    "layers": [
        L("cherry", circle(MID, 258, 50), "cherry"),
        L("swirl-3", pill(MID, 362, 266, 124), "frosting"),
        L("swirl-2", pill(MID, 452, 380, 138), "frosting"),
        L("swirl-1", pill(MID, 554, 480, 152), "frosting"),
        L("liner", liner(586, 812, 214, 158), "liner"),
    ]})

# ================================================================ C. Plated
CONCEPTS.append({
    "id": "plated", "title": "Plated",
    "line": "The same dome, set on a white plate — more framing, more dessert.",
    "layers": [
        L("cherry", circle(MID, 244, 46), "cherry"),
        L("frosting", dome(MID, 516, 206, 230), "frosting"),
        L("liner", liner(514, 738, 182, 136, 12, 32), "liner"),
        L("plate", ellipse(MID, 768, 348, 58), "plate"),
    ]})

# ============================================================== D. Overhead
CONCEPTS.append({
    "id": "overhead", "title": "Overhead",
    "line": "The cupcake from directly above \u2014 perfectly round and symmetric, and the one that holds smallest.",
    "layers": [
        L("cherry", circle(MID, MID, 78), "cherry"),
        L("frosting", circle(MID, MID, 252), "frosting"),
        L("liner", scalloped(MID, MID, 318, 18, 26), "liner"),
    ]})


# -------------------------------------------------------------- the mask
def squircle(size=C, n=5.0, steps=76):
    a = size / 2.0
    pts = []
    for i in range(steps + 1):
        th = 2 * math.pi * i / steps
        ct, st = math.cos(th), math.sin(th)
        r = a / (abs(ct) ** n + abs(st) ** n) ** (1 / n) if (ct or st) else a
        pts.append((a + r * ct, a + r * st))
    return "M " + " L ".join(P(*p) for p in pts) + " Z"


def emit():
    return {"canvas": C, "squircle": squircle(), "bg": BG,
            "liners": LINERS, "concepts": CONCEPTS}


def by_id(cid):
    for c in CONCEPTS:
        if c["id"] == cid:
            return c
    raise KeyError(cid)


if __name__ == "__main__":
    print(json.dumps(emit()))
