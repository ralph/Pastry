"""Pastry app icon, round 2: a simplified layered cake slice (side view)
with Apple-emoji-style scissors seen from the side, at an angle.
Canvas 1024x1024, y-down. Light backgrounds, colourful accents, dark scissors."""
import json, math

C = 1024.0

def P(x, y):
    return f"{x:.1f} {y:.1f}".replace(".0", "")

def poly(pts):
    return "M " + P(*pts[0]) + " " + " ".join("L " + P(*p) for p in pts[1:]) + " Z"

def round_poly(pts, radii):
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
        cross = u1[0]*u2[1] - u1[1]*u2[0]
        corners.append(((v[0]+u1[0]*t, v[1]+u1[1]*t),
                        (v[0]+u2[0]*t, v[1]+u2[1]*t),
                        t * math.tan(theta/2), 1 if cross < 0 else 0))
    d = "M " + P(*corners[0][0])
    for a, b, r, sw in corners:
        d += " L " + P(*a)
        d += (f" A {r:.1f} {r:.1f} 0 0 {sw} {P(*b)}" if r > 0.01 else " L " + P(*b))
    return d + " Z"

def circle(cx, cy, r):
    return (f"M {P(cx-r, cy)} A {r:.1f} {r:.1f} 0 0 1 {P(cx+r, cy)} "
            f"A {r:.1f} {r:.1f} 0 0 1 {P(cx-r, cy)} Z")

def ring(cx, cy, r_out, thick):
    ri = r_out - thick
    return (f"M {P(cx-r_out, cy)} A {r_out:.1f} {r_out:.1f} 0 0 1 {P(cx+r_out, cy)} "
            f"A {r_out:.1f} {r_out:.1f} 0 0 1 {P(cx-r_out, cy)} Z "
            f"M {P(cx-ri, cy)} A {ri:.1f} {ri:.1f} 0 0 0 {P(cx+ri, cy)} "
            f"A {ri:.1f} {ri:.1f} 0 0 0 {P(cx-ri, cy)} Z")

def taper(p0, p1, w0, w1, curve=0.0):
    """Tapered limb from p0 (width w0) to p1 (width w1), rounded tip."""
    ax, ay = p0; bx, by = p1
    dx, dy = bx-ax, by-ay
    L = math.hypot(dx, dy) or 1e-9
    ux, uy = dx/L, dy/L
    nx, ny = -uy, ux
    mx, my = (ax+bx)/2 + nx*curve, (ay+by)/2 + ny*curve
    wm = (w0 + w1) / 2 * 1.04
    A = (ax + nx*w0, ay + ny*w0); B = (mx + nx*wm, my + ny*wm); D = (bx + nx*w1, by + ny*w1)
    E = (bx - nx*w1, by - ny*w1); F = (mx - nx*wm, my - ny*wm); G = (ax - nx*w0, ay - ny*w0)
    return (f"M {P(*A)} Q {P(*B)} {P(*D)} A {w1:.1f} {w1:.1f} 0 0 0 {P(*E)} "
            f"Q {P(*F)} {P(*G)} Z")

def xform(d, deg, tx, ty, sc=1.0):
    """Scale about the local origin, rotate by deg, then translate."""
    th = math.radians(deg); co, si = math.cos(th), math.sin(th)
    def pt(x, y):
        x, y = x * sc, y * sc
        return f"{x*co - y*si + tx:.1f} {x*si + y*co + ty:.1f}".replace(".0", "")
    def rad(v):
        return f"{float(v)*sc:.1f}".replace(".0", "")
    out, i, t = [], 0, d.split()
    while i < len(t):
        k = t[i]
        if k in ("M", "L"):
            out += [k, pt(float(t[i+1]), float(t[i+2]))]; i += 3
        elif k == "Q":
            out += [k, pt(float(t[i+1]), float(t[i+2])), pt(float(t[i+3]), float(t[i+4]))]; i += 5
        elif k == "A":
            out += [k, rad(t[i+1]), rad(t[i+2]), t[i+3], t[i+4], t[i+5],
                    pt(float(t[i+6]), float(t[i+7]))]; i += 8
        else:
            out.append(k); i += 1
    return " ".join(out)

# ------------------------------------------------------------------ pieces
def cake(x0, x1, ytop, ybot, dome=20, r_bot=30):
    """Side view of a layer-cake slice. Returns bands front-to-back plus the
    cream-layer fruit bits. Proportions follow the reference photo:
    thick frosting cap, sponge, cream, sponge."""
    h = ybot - ytop
    f1 = ytop + h * 0.285          # frosting / sponge A
    c0 = ytop + h * 0.515          # sponge A / cream
    c1 = ytop + h * 0.700          # cream / sponge B
    cx = (x0 + x1) / 2
    frosting = (f"M {P(x0, f1)} L {P(x0, ytop + dome)} "
                f"Q {P(cx, ytop - dome)} {P(x1, ytop + dome)} L {P(x1, f1)} Z")
    w = x1 - x0
    bits = (round_poly([(x0 + w*0.11, c0 + 15), (x0 + w*0.31, c0 + 11),
                        (x0 + w*0.33, c1 - 13), (x0 + w*0.13, c1 - 10)], 11) + " " +
            round_poly([(x0 + w*0.48, c0 + 13), (x0 + w*0.64, c0 + 16),
                        (x0 + w*0.67, c1 - 11), (x0 + w*0.51, c1 - 14)], 11))
    return {
        "frosting": frosting,
        "spongeA": poly([(x0, f1), (x1, f1), (x1, c0), (x0, c0)]),
        "cream":   poly([(x0, c0), (x1, c0), (x1, c1), (x0, c1)]),
        "spongeB": round_poly([(x0, c1), (x1, c1), (x1, ybot), (x0, ybot)], [0, 0, r_bot, r_bot]),
        "bits": bits,
        "top": ytop,
    }

def cherry(cx, cy, r, stem_to, stem_w=11):
    return {"fruit": circle(cx, cy, r),
            "stem": taper((cx, cy - r * 0.55), stem_to, stem_w, stem_w * 0.55, curve=-22)}

def wedge(cx, cy, s, deg=0):
    """A simplified pineapple chunk."""
    return xform(round_poly([(-s*0.52, s*0.46), (s*0.10, -s*0.58), (s*0.54, s*0.40)], s*0.22),
                 deg, cx, cy)

def scissors(pivot, deg, scale=1.0):
    """Classic scissors seen from the side. Two loops on the -x side, two
    blades on the +x side; each arm runs from its loop THROUGH the pivot to the
    blade on the opposite side, so the blades genuinely cross. Returns rings and
    body as separate paths: they overlap, and a single path would cancel itself
    under either fill rule."""
    px, py = pivot
    rings, body = [], []
    for s_ in (-1, 1):
        rings.append(ring(-215, 128 * s_, 76, 31))
        # neck: loop -> blade root, bowed outward
        body.append(taper((-156, 90 * s_), (-14, 10 * s_), 26, 38, curve=22 * s_))
        # blade: root reaches past the centreline (that is the crossing),
        # straight cutting edge, blunt rounded point
        body.append(round_poly([(-46, 16 * s_), (22, -70 * s_),
                                (370, -128 * s_), (402, -100 * s_)],
                               [18, 26, 14, 12]))
    body.append(circle(0, 0, 36))        # the pivot boss, as on real scissors
    return {"rings": xform(" ".join(rings), deg, px, py, scale),
            "body": xform(" ".join(body), deg, px, py, scale)}

# Only the scissors change between appearances. Everything edible keeps one
# palette in every appearance, which is what the HIG asks for and keeps
# icon.json down to a single dark specialization per changing layer.
TONES = {
    "frosting": ("#FFFFFF", "#FFFFFF"),
    "sponge":   ("#F9D89B", "#F9D89B"),
    "cream":    ("#FFF6E6", "#FFF6E6"),
    "fruit":    ("#FFC42B", "#FFC42B"),
    "cherry":   ("#E8384C", "#E8384C"),
    "stem":     ("#4E7F3C", "#4E7F3C"),
    "steel":    ("#332E3B", "#A7AFC4"),
    "steel2":   ("#453F4F", "#A7AFC4"),
}

COLORWAYS = {
    "rose":    (["#FFF0EB", "#FFC6CE"], ["#5C3039", "#2A1419"], "Rose"),
    "vanilla": (["#FFFAEE", "#FFD79B"], ["#4E3A20", "#241A0C"], "Vanilla"),
    "mint":    (["#EEFBF4", "#B6E9D0"], ["#1E443A", "#0D211B"], "Mint"),
    "sky":     (["#F0F6FF", "#C2D4FF"], ["#263450", "#101726"], "Sky"),
}

def L(name, d, tone, opacity=1.0):
    lt, dk = TONES[tone]
    return {"name": name, "d": d, "light": lt, "dark": dk,
            "opacity": opacity, "tone": tone}

def build(cake_box, cherry_spec, sc, wedge_spec=None):
    ck = cake(*cake_box)
    ch = cherry(*cherry_spec)
    layers = [
        L("scissors-rings", sc["rings"], "steel"),
        L("scissors-body", sc["body"], "steel"),
        L("cherry", ch["fruit"], "cherry"),
        L("cherry-stem", ch["stem"], "stem"),
    ]
    if wedge_spec:
        layers.append(L("pineapple", wedge(*wedge_spec), "fruit"))
    layers += [
        L("fruit-bits", ck["bits"], "fruit"),
        L("frosting", ck["frosting"], "frosting"),
        L("cream", ck["cream"], "cream"),
        L("sponge-top", ck["spongeA"], "sponge"),
        L("sponge-bottom", ck["spongeB"], "sponge"),
    ]
    return layers

CONCEPTS = [
    {"id": "level", "title": "Level",
     "line": "Scissors held almost level at the left, blades closing on the top of the slice.",
     "layers": build((330, 870, 430, 846), (800, 378, 50, (742, 292)),
                     scissors((350, 370), 14, 0.66),
                     wedge_spec=(700, 388, 110, -10))},
    {"id": "angled", "title": "Angled",
     "line": "Scissors swung down from the upper left, one blade already into the frosting.",
     "layers": build((330, 870, 440, 856), (800, 388, 50, (742, 302)),
                     scissors((345, 330), 32, 0.64),
                     wedge_spec=(700, 398, 110, -12))},
    {"id": "bold", "title": "Bold Scissors",
     "line": "Bigger scissors, tighter slice \u2014 the tool leads and the cake answers.",
     "layers": build((420, 880, 420, 836), (820, 364, 46, (766, 284)),
                     scissors((360, 400), 16, 0.74),
                     wedge_spec=(730, 372, 104, -10))},
]

def squircle(size=C, n=5.0, steps=76):
    a = size / 2.0
    pts = []
    for i in range(steps + 1):
        th = 2 * math.pi * i / steps
        ct, st = math.cos(th), math.sin(th)
        r = a / (abs(ct)**n + abs(st)**n)**(1/n) if (ct or st) else a
        pts.append((a + r*ct, a + r*st))
    return poly(pts)

print(json.dumps({"canvas": C, "squircle": squircle(),
                  "bg": {"light": COLORWAYS["rose"][0], "dark": COLORWAYS["rose"][1]},
                  "colorways": COLORWAYS, "concepts": CONCEPTS}))
