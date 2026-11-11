"""Geometry for Pastry app-icon concepts. Canvas 1024x1024, y-down.
Angles: degrees, 0=+x(right), 90=down, 180=left, 270=up."""
import json, math

C = 1024.0
MID = C / 2.0

def P(x, y):
    return f"{x:.1f} {y:.1f}".replace(".0", "")

def poly(pts, close=True):
    d = "M " + P(*pts[0]) + " " + " ".join("L " + P(*p) for p in pts[1:])
    return d + " Z" if close else d

def rr(x, y, w, h, r):
    """Rounded rect as a path."""
    r = min(r, w / 2, h / 2)
    return (f"M {x+r:.0f} {y:.0f} H {x+w-r:.0f} A {r:.1f} {r:.1f} 0 0 1 {x+w:.0f} {y+r:.0f} "
            f"V {y+h-r:.0f} A {r:.1f} {r:.1f} 0 0 1 {x+w-r:.0f} {y+h:.0f} "
            f"H {x+r:.0f} A {r:.1f} {r:.1f} 0 0 1 {x:.0f} {y+h-r:.0f} "
            f"V {y+r:.0f} A {r:.1f} {r:.1f} 0 0 1 {x+r:.0f} {y:.0f} Z")

def tapered_arc(cx, cy, r_mid, half_c, half_e, a0, a1, steps=44, bulge=0.0):
    """Crescent/croissant: arc swept a0->a1 whose half-thickness eases from
    half_e at the ends to half_c at the middle. Returns a closed path."""
    outer, inner = [], []
    for i in range(steps + 1):
        t = i / steps
        a = math.radians(a0 + (a1 - a0) * t)
        # smooth bell: 1 at centre, 0 at both ends
        bell = math.sin(math.pi * t) ** 0.72
        ht = half_e + (half_c - half_e) * bell
        rm = r_mid + bulge * bell
        ca, sa = math.cos(a), math.sin(a)
        outer.append((cx + (rm + ht) * ca, cy + (rm + ht) * sa))
        inner.append((cx + (rm - ht) * ca, cy + (rm - ht) * sa))
    return poly(outer + list(reversed(inner)))

def blade(pivot, tip, w_pivot, w_tip, curve=0.0):
    """Tapered scissor blade from pivot to tip, optionally bowed."""
    px, py = pivot; tx, ty = tip
    dx, dy = tx - px, ty - py
    L = math.hypot(dx, dy)
    ux, uy = dx / L, dy / L
    nx, ny = -uy, ux                      # left normal
    mx, my = (px + tx) / 2 + nx * curve, (py + ty) / 2 + ny * curve
    wm = (w_pivot + w_tip) / 2 * 1.06
    a = (px + nx * w_pivot, py + ny * w_pivot)
    b = (mx + nx * wm, my + ny * wm)
    c = (tx + nx * w_tip, ty + ny * w_tip)
    d = (tx - nx * w_tip, ty - ny * w_tip)
    e = (mx - nx * wm, my - ny * wm)
    f = (px - nx * w_pivot, py - ny * w_pivot)
    return (f"M {P(*a)} Q {P(*b)} {P(*c)} "
            f"A {w_tip:.1f} {w_tip:.1f} 0 0 1 {P(*d)} "
            f"Q {P(*e)} {P(*f)} Z")

def ring(cx, cy, r_out, thick, squash=1.0, rot=0.0):
    """Annulus (handle ring) as one even-odd path; optional ellipse squash."""
    ro_x, ro_y = r_out, r_out * squash
    ri_x, ri_y = r_out - thick, (r_out - thick) * squash
    def ell(rx, ry, sweep):
        return (f"M {cx-rx:.1f} {cy:.1f} "
                f"A {rx:.1f} {ry:.1f} {rot} 0 {sweep} {cx+rx:.1f} {cy:.1f} "
                f"A {rx:.1f} {ry:.1f} {rot} 0 {sweep} {cx-rx:.1f} {cy:.1f} Z")
    return ell(ro_x, ro_y, 1) + " " + ell(ri_x, ri_y, 0)

def arm(p0, p1, w0, w1):
    return blade(p0, p1, w0, w1)


def round_poly(pts, radii):
    """Polygon with per-vertex rounded corners. pts in path order."""
    n = len(pts)
    if isinstance(radii, (int, float)):
        radii = [radii] * n
    corners = []
    for i in range(n):
        v = pts[i]; pv = pts[i-1]; nx_ = pts[(i+1) % n]
        d1 = (pv[0]-v[0], pv[1]-v[1]); d2 = (nx_[0]-v[0], nx_[1]-v[1])
        l1 = math.hypot(*d1) or 1e-9; l2 = math.hypot(*d2) or 1e-9
        u1 = (d1[0]/l1, d1[1]/l1); u2 = (d2[0]/l2, d2[1]/l2)
        dot = max(-1.0, min(1.0, u1[0]*u2[0] + u1[1]*u2[1]))
        theta = math.acos(dot)
        if theta < 1e-6 or abs(theta - math.pi) < 1e-6:
            corners.append((v, v, 0.0, 1)); continue
        t = min(radii[i] / math.tan(theta/2), l1/2, l2/2)
        r_eff = t * math.tan(theta/2)
        cross = u1[0]*u2[1] - u1[1]*u2[0]
        corners.append(((v[0]+u1[0]*t, v[1]+u1[1]*t),
                        (v[0]+u2[0]*t, v[1]+u2[1]*t), r_eff, 1 if cross < 0 else 0))
    d = "M " + P(*corners[0][0])
    for a, b, r, sw in corners:
        d += " L " + P(*a)
        d += (f" A {r:.1f} {r:.1f} 0 0 {sw} {P(*b)}" if r > 0.01 else " L " + P(*b))
    return d + " Z"

def shift(d, dx, dy):
    """Translate every coordinate pair in a generated path (paths here use
    absolute 'x y' pairs after M/L and after the A flag triplet)."""
    out, i, toks = [], 0, d.split()
    while i < len(toks):
        t = toks[i]
        if t in ("M", "L"):
            out.append(t); out.append(f"{float(toks[i+1])+dx:.2f}"); out.append(f"{float(toks[i+2])+dy:.2f}"); i += 3
        elif t == "Q":
            out.append(t)
            for k in range(4):
                out.append(f"{float(toks[i+1+k])+(dx if k % 2 == 0 else dy):.2f}")
            i += 5
        elif t == "A":
            out += [t, toks[i+1], toks[i+2], toks[i+3], toks[i+4], toks[i+5]]
            out.append(f"{float(toks[i+6])+dx:.2f}"); out.append(f"{float(toks[i+7])+dy:.2f}"); i += 8
        elif t in ("H",):
            out.append(t); out.append(f"{float(toks[i+1])+dx:.2f}"); i += 2
        elif t in ("V",):
            out.append(t); out.append(f"{float(toks[i+1])+dy:.2f}"); i += 2
        else:
            out.append(t); i += 1
    return " ".join(out)

def arc_shift(cx, cy, r_mid, half_c, half_e, a0, a1, dist, ang, **kw):
    """tapered_arc translated `dist` along direction `ang` (deg)."""
    d = tapered_arc(cx, cy, r_mid, half_c, half_e, a0, a1, **kw)
    return shift(d, dist*math.cos(math.radians(ang)), dist*math.sin(math.radians(ang)))

# ---------------------------------------------------------------- palette
PAL = {
    "pastry":  ("#FFF6E4", "#FFEFD4"),   # (light appearance, dark appearance)
    "pastry2": ("#FBE4BC", "#F0D3A6"),
    "cream":   ("#FFCF86", "#F2BE74"),
    "crust":   ("#D2791F", "#C06C19"),
    "steel":   ("#FFFFFF", "#F2F7FF"),
    "steel2":  ("#E2ECF7", "#D2DFEE"),
}
BG_LIGHT = ["#FFD688", "#E8832B"]
BG_DARK  = ["#6E4320", "#23130A"]

def L(name, path, tone, opacity=1.0, glass=True):
    lt, dk = PAL[tone]
    return {"name": name, "d": path, "light": lt, "dark": dk,
            "opacity": opacity, "tone": tone, "glass": glass}

CONCEPTS = []

# ============================================================== A. Snip
# The seed, played straight: open scissors snipping a croissant.
ax, ay, ar = 468, 552, 198
piv = (710, 322)
CONCEPTS.append({
    "id": "snip",
    "title": "Snip",
    "line": "The seed played straight \u2014 open scissors closing on a croissant.",
    "layers": [
        L("handles", " ".join([
            arm(piv, (638, 240), 30, 24), arm(piv, (810, 250), 30, 24),
            ring(628, 204, 62, 30), ring(820, 216, 62, 30)]), "steel2"),
        L("blades", " ".join([
            blade(piv, (590, 546), 38, 20, curve=-5),
            blade(piv, (800, 530), 38, 20, curve=5)]), "steel"),
        L("croissant", tapered_arc(ax, ay, ar, 90, 26, 340, 560, bulge=10), "pastry2"),
    ],
})

# ====================================================== B. Mille-feuille
# Clipboard history is literally lamination; the newest clipping lifted clear.
BX, BW, BH, BR = 236, 552, 124, 62
CONCEPTS.append({
    "id": "millefeuille",
    "title": "Mille-feuille",
    "line": "Clipboard history as lamination \u2014 stacked pastry layers, newest clipping lifted clear.",
    "layers": [
        L("clipping", rr(BX + 64, 266, BW - 128, BH, BR), "pastry"),
        L("slab-top", rr(BX, 480, BW, BH, BR), "pastry"),
        L("cream",    rr(BX + 30, 618, BW - 60, 56, 28), "cream"),
        L("slab-bot", rr(BX, 688, BW, BH, BR), "pastry"),
    ],
})

# ========================================================= C. Cut Crescent
# One bold crescent with a piece cleanly snipped off its end.
cx3, cy3, r3 = 512, 520, 208
CONCEPTS.append({
    "id": "crescent",
    "title": "Cut Crescent",
    "line": "The most mark-like \u2014 a crescent with a piece cleanly snipped off its end.",
    "layers": [
        L("piece", arc_shift(cx3, cy3, r3, 80, 34, 270, 332, 56, -61), "pastry"),
        L("crescent", tapered_arc(cx3, cy3, r3, 96, 34, -13, 258), "pastry2"),
    ],
})

# ============================================================ D. Clipping
# A square of pastry with its corner snipped off; a slice behind it = history.
FX0, FY0, FX1, FY1, CH = 262, 366, 746, 850, 176
front = round_poly([(FX0, FY0), (FX1 - CH, FY0), (FX1, FY0 + CH), (FX1, FY1), (FX0, FY1)],
                   [114, 30, 30, 114, 114])
corner = shift(round_poly([(FX1 - CH, FY0), (FX1, FY0), (FX1, FY0 + CH)], [26, 30, 26]), 68, -72)
CONCEPTS.append({
    "id": "clipping",
    "title": "Clipping",
    "line": "A slice of pastry with its corner snipped off and lifted away; the slice behind is the history.",
    "layers": [
        L("corner", corner, "pastry"),
        L("front", front, "pastry"),
        L("behind", rr(188, 272, 438, 438, 112), "cream"),
    ],
})

# ------------------------------------------------------------ squircle mask
def squircle(size=C, n=5.0, steps=76):
    a = size / 2.0
    pts = []
    for i in range(steps + 1):
        th = 2 * math.pi * i / steps
        ct, st = math.cos(th), math.sin(th)
        rx = a / (abs(ct) ** n + abs(st) ** n) ** (1 / n) if (ct or st) else a
        pts.append((a + rx * ct, a + rx * st))
    return poly(pts)

OUT = {
    "canvas": C,
    "squircle": squircle(),
    "bg": {"light": BG_LIGHT, "dark": BG_DARK},
    "concepts": CONCEPTS,
}
print(json.dumps(OUT))
