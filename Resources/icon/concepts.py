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
    return (f"M {P(*A)} Q {P(*B)} {P(*D)} A {w1:.1f} {w1:.1f} 0 0 1 {P(*E)} "
            f"Q {P(*F)} {P(*G)} Z")

def xform(d, deg, tx, ty):
    """Rotate a path about the origin by deg, then translate."""
    th = math.radians(deg); co, si = math.cos(th), math.sin(th)
    def pt(x, y):
        return f"{x*co - y*si + tx:.1f} {x*si + y*co + ty:.1f}".replace(".0", "")
    out, i, t = [], 0, d.split()
    while i < len(t):
        k = t[i]
        if k in ("M", "L"):
            out += [k, pt(float(t[i+1]), float(t[i+2]))]; i += 3
        elif k == "Q":
            out += [k, pt(float(t[i+1]), float(t[i+2])), pt(float(t[i+3]), float(t[i+4]))]; i += 5
        elif k == "A":
            out += [k, t[i+1], t[i+2], t[i+3], t[i+4], t[i+5], pt(float(t[i+6]), float(t[i+7]))]; i += 8
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

def blade_shape(length, base_half, tip_half, splay, side):
    """One blade in local coords: base at the pivot, tip at -x.
    `side` is -1 (upper) or +1 (lower). The inner edge stays near y=0 so the
    two blades meet at the pivot the way real scissors do."""
    drop = length * splay * side
    return round_poly([(18, side * base_half),
                       (-length, drop - side * tip_half),
                       (-length, drop + side * tip_half),
                       (10, side * 5)],
                      [14, tip_half * 0.82, tip_half * 0.82, 8])

def scissors(pivot, deg, blade_len, arm_len, loop_r, spread, w=1.0):
    """Open scissors seen from the side, built along a local +x axis running
    pivot -> handles, blades along -x, then rotated into place."""
    px, py = pivot
    base_half, tip_half = 52 * w, 16 * w
    blades = (blade_shape(blade_len, base_half, tip_half, 0.145, -1) + " " +
              blade_shape(blade_len, base_half, tip_half, 0.145, 1))
    handles = (taper((0, 0), (arm_len, -spread * 0.70), 25 * w, 19 * w) + " " +
               taper((0, 0), (arm_len, spread * 0.70), 25 * w, 19 * w) + " " +
               ring(arm_len + loop_r * 0.54, -spread, loop_r, loop_r * 0.42) + " " +
               ring(arm_len + loop_r * 0.54, spread, loop_r, loop_r * 0.42))
    return {"blades": xform(blades, deg, px, py),
            "handles": xform(handles, deg, px, py),
            "all": xform(blades + " " + handles, deg, px, py)}

# ------------------------------------------------------------------ palette
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
        L("scissors-handles", sc["handles"], "steel2"),
        L("scissors-blades", sc["blades"], "steel"),
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
    {"id": "slice-snip", "title": "Slice and Snip",
     "line": "Scissors angled in from the upper right, blades closing across the slice.",
     "layers": build((170, 650, 400, 830), (280, 352, 54, (340, 262)),
                     scissors((700, 335), -40, 215, 115, 50, 56))},
    {"id": "cherry-top", "title": "Cherry Top",
     "line": "Cake forward: a big slice with cherry and pineapple, scissors snipping the top corner.",
     "layers": build((200, 720, 420, 850), (330, 368, 56, (396, 274)),
                     scissors((740, 310), -48, 180, 85, 40, 44, w=0.85),
                     wedge_spec=(470, 364, 120, 14))},
    {"id": "big-cut", "title": "Big Cut",
     "line": "Scissors forward: a large pair driven diagonally down into a smaller slice.",
     "layers": build((150, 560, 470, 850), (250, 420, 48, (304, 334)),
                     scissors((640, 430), -33, 300, 150, 62, 72, w=1.2))},
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
