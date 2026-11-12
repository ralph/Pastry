"""Pastry app icon: the cupcake seen from the side with the camera slightly
above -- a three-quarter view, between the flat elevation and the overhead.

What the raised camera buys, geometrically:
  * the case rim becomes an ellipse, so the case's top edge is the FRONT half
    of that ellipse and dips lowest at the centre;
  * the case's pleats fan out, naturally compressed towards both edges,
    because a vertical line at angle t projects to cx + rx*cos(t);
  * every turn of the swirl is an ellipse rather than a straight band.

Canvas 1024x1024, y-down.
"""
import json
import math

C = 1024.0
MID = 512.0


def P(x, y):
    return f"{x:.1f} {y:.1f}".replace(".0", "")


def ellipse(cx, cy, rx, ry):
    return (f"M {P(cx - rx, cy)} A {rx:.1f} {ry:.1f} 0 0 1 {P(cx + rx, cy)} "
            f"A {rx:.1f} {ry:.1f} 0 0 1 {P(cx - rx, cy)} Z")


def circle(cx, cy, r):
    return ellipse(cx, cy, r, r)


def dome(cx, cy, rx, ry):
    """Upper half of an ellipse, flat along y = cy."""
    return f"M {P(cx - rx, cy)} A {rx:.1f} {ry:.1f} 0 0 1 {P(cx + rx, cy)} Z"


def arc_pt(cx, cy, rx, ry, t):
    """A point on an ellipse. t is radians, 0 = right, pi/2 = BOTTOM (y-down),
    pi = left -- so the front half of a rim runs t: pi -> 0."""
    return (cx + rx * math.cos(t), cy + ry * math.sin(t))


def case(rim_y, rim_rx, rim_ry, base_y, base_rx, base_ry):
    """The paper case. Its top edge is the front half of the rim ellipse, so it
    dips lowest at the centre; its bottom edge is the front half of the base."""
    return (f"M {P(MID - rim_rx, rim_y)} "
            f"A {rim_rx:.1f} {rim_ry:.1f} 0 0 0 {P(MID + rim_rx, rim_y)} "
            f"L {P(MID + base_rx, base_y)} "
            f"A {base_rx:.1f} {base_ry:.1f} 0 0 1 {P(MID - base_rx, base_y)} Z")


def pleats(rim_y, rim_rx, rim_ry, base_y, base_rx, base_ry, n=12, step=3):
    """Every other pleat of the case, as a shaded wedge. Each runs from the rim
    arc down to the base arc along a line of constant angle, which is what makes
    them compress towards the edges on their own."""
    out = []
    for k in range(0, n, 2):
        t0 = math.pi * (1 - k / n)
        t1 = math.pi * (1 - (k + 1) / n)
        top = [arc_pt(MID, rim_y, rim_rx, rim_ry, t0 + (t1 - t0) * i / step)
               for i in range(step + 1)]
        bot = [arc_pt(MID, base_y, base_rx, base_ry, t1 + (t0 - t1) * i / step)
               for i in range(step + 1)]
        pts = top + bot
        out.append("M " + " L ".join(P(*p) for p in pts) + " Z")
    return " ".join(out)


def swirl_turns(n, y0=542, y1=346, rx0=206, rx1=112, ry0=76, ry1=48, wobble=13):
    """n turns of piped frosting, interpolated between a fixed bottom and top
    ellipse. Keeping the ends fixed means the swirl's height and taper stay put
    however many turns there are -- only the banding gets coarser or finer.
    The small alternating nudge off-centre is what reads as a spiral."""
    out = []
    for i in range(n):
        t = i / (n - 1)  # 0 at the base, 1 at the tip
        out.append((MID + wobble * (1 - t) * math.sin(i * 2.3),
                    y0 + (y1 - y0) * t,
                    rx0 + (rx1 - rx0) * t,
                    ry0 + (ry1 - ry0) * t))
    return out


def swirl(turns):
    """One ellipse per turn of piped frosting, biggest and lowest first. Each
    turn carries its own top-light gradient, so where the next turn overlaps it
    the darker lower edge shows through as a band -- that banding is the swirl."""
    return [ellipse(cx, cy, rx, ry) for (cx, cy, rx, ry) in turns]


# -------------------------------------------------------------------- palette
# Desaturated pastels throughout. The cherry is the only saturated thing.
G = {
    "case":     (("#CBD9E0", "#9FB4C0"), (0, 0, 0, 1)),
    "pleat":    (("#B9CAD3", "#8EA5B2"), (0, 0, 0, 1)),
    "cake":     (("#EFDFC2", "#D3B88F"), (0, 0, 0, 1)),
    "frosting": (("#FFFCF6", "#E4D3C0"), (0, 0, 0, 1)),
    "cherry":   (("#F2566B", "#C8102E"), (0.3, 0, 0.75, 1)),
    "stem":     (("#A8906F", "#7E674B"), (0, 0, 0, 1)),
    "shine":    (("#FFFFFF", "#FFFFFF"), (0, 0, 0, 1)),
}

BG = {"light": ("#FFF3EF", "#FFC8D2"), "dark": ("#5E323B", "#2B151A")}

CASES = {
    "slate":  ("#CBD9E0", "#9FB4C0"),
    "sage":   ("#CCDCD1", "#A0BBAA"),
    "lilac":  ("#D6CFE2", "#AEA3C6"),
    "sand":   ("#E6DAC8", "#C4B197"),
    "rose":   ("#EDD5D8", "#CFAEB3"),
}


def L(name, d, tone, opacity=1.0):
    stops, direction = G[tone]
    return {"name": name, "d": d, "tone": tone, "opacity": opacity,
            "stops": list(stops), "dir": list(direction)}


# Shared case geometry for the three-quarter variants.
RIM_Y, RIM_RX, RIM_RY = 630, 232, 58
BASE_Y, BASE_RX, BASE_RY = 822, 158, 38

CASE_D = case(RIM_Y, RIM_RX, RIM_RY, BASE_Y, BASE_RX, BASE_RY)
PLEAT_D = pleats(RIM_Y, RIM_RX, RIM_RY, BASE_Y, BASE_RX, BASE_RY)
CAKE_D = ellipse(MID, 656, 248, 104)

SWIRL = [(MID, 540, 206, 72), (500, 470, 176, 64),
         (524, 408, 146, 56), (506, 352, 112, 46), (MID, 306, 72, 36)]

CHERRY = circle(MID, 256, 52)
STEM = ("M 504 212 Q 520 158 566 136 L 578 156 Q 540 176 524 216 Z")
SHINE = ellipse(490, 238, 16, 10)


def cherry_layers():
    return [L("cherry-shine", SHINE, "shine", 0.75),
            L("cherry", CHERRY, "cherry"),
            L("cherry-stem", STEM, "stem")]


CONCEPTS = []

# Layers are listed FRONT to BACK, matching icon.json's convention.


def variant(cid, title, line, n):
    return {"id": cid, "title": title, "line": line,
            "layers": cherry_layers()
            + [L(f"swirl-{i}", d, "frosting")
               for i, d in enumerate(reversed(swirl(swirl_turns(n))))]
            + [L("pleats", PLEAT_D, "pleat"),
               L("case", CASE_D, "case"),
               L("cake", CAKE_D, "cake")]}


CONCEPTS.append(variant(
    "tq5", "Five turns", "Where we were \u2014 the finest banding.", 5))
CONCEPTS.append(variant(
    "tq4", "Four turns", "One turn fewer. Same height and taper, slightly coarser bands.", 4))
CONCEPTS.append(variant(
    "tq3", "Three turns", "Two turns fewer \u2014 the quietest, and the closest to a plain cap.", 3))


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
            "cases": CASES, "concepts": CONCEPTS}


if __name__ == "__main__":
    print(json.dumps(emit()))
