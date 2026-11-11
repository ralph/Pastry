import json, subprocess, sys
d = json.load(open('geom.json'))
SIZES = [320, 128, 64, 32, 16]
PAD, GAP, ROWH = 20, 26, 352

defs, body = [], []
def tile(c, mode, size, x, y, uid):
    bg = d['bg'][mode]
    s = size / 1024.0
    defs.append(f'<clipPath id="cp{uid}"><path d="{d["squircle"]}"/></clipPath>')
    defs.append(f'<linearGradient id="bg{uid}" x1="0" y1="0" x2="0" y2="1">'
                f'<stop offset="0" stop-color="{bg[0]}"/><stop offset="1" stop-color="{bg[1]}"/></linearGradient>')
    ls = "".join(f'<path d="{l["d"]}" fill="{l[mode]}" fill-rule="evenodd" opacity="{l["opacity"]}"/>'
                 for l in reversed(c['layers']))
    return (f'<g transform="translate({x:.2f},{y:.2f}) scale({s:.6f})" clip-path="url(#cp{uid})">'
            f'<rect width="1024" height="1024" fill="url(#bg{uid})"/>{ls}</g>')

n = 0
W = PAD*2 + 320 + GAP + sum(SIZES[1:]) + GAP*len(SIZES[1:]) + 120
rows = len(d['concepts']) * 2
H = PAD*2 + rows*ROWH
for ci, c in enumerate(d['concepts']):
    for mi, mode in enumerate(('light','dark')):
        ry = PAD + (ci*2+mi)*ROWH
        body.append(f'<rect x="0" y="{ry-8}" width="{W}" height="{ROWH-6}" '
                    f'fill="{"#c9c9c9" if mi==0 else "#4a4a4a"}"/>')
        body.append(f'<text x="{PAD}" y="{ry+340}" font-family="Helvetica" font-size="15" '
                    f'fill="{"#111" if mi==0 else "#eee"}">{c["title"]} — {mode}</text>')
        x = PAD
        for s in SIZES:
            n += 1
            body.append(tile(c, mode, s, x, ry + (320 - s)/2 + 0, n))
            x += s + GAP

svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">'
       f'<defs>{"".join(defs)}</defs><rect width="{W}" height="{H}" fill="#8a8a8a"/>'
       f'{"".join(body)}</svg>')
open('sheet.svg','w').write(svg)
print(W, H)
