"""Textures for the Warmth interface, drawn procedurally into Media/.

    python -I tools/gen-media.py                 write every texture (and Media/logo-512.png for the store page)
    python -I tools/gen-media.py --check         exit 1 if a file in Media/ differs from what this script draws
    python -I tools/gen-media.py --preview DIR   also write PNG previews on the addon's dark background

Standard library only, deterministic output: uncompressed 32-bit TGA (type 2, 8 alpha bits, bottom-left origin),
power-of-two sizes. Shapes are signed distance fields; coverage = clamp(0.5 - d) gives a one-pixel antialiased
edge. "White" textures carry the shape in alpha so the Lua side tints them with SetVertexColor; the flame and the
logo are coloured.
"""
import math
import os
import struct
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MEDIA = os.path.join(ROOT, "Media")
FRAMES, CELL = 8, 128  # the flame sheet: 8 cells of 128 px in a row

EMBER, DEEP, CORE = (1.0, 0.63, 0.20), (0.91, 0.36, 0.09), (1.0, 0.90, 0.56)
FIRE = (DEEP, EMBER, CORE)
VIOLET = ((0.40, 0.19, 0.78), (0.66, 0.43, 0.98), (0.94, 0.86, 1.0))  # Violet Dust thrown into the fire
LOG, LOG_DARK, LOG_END = (0.42, 0.26, 0.15), (0.29, 0.17, 0.10), (0.72, 0.52, 0.33)
NIGHT = (0.070, 0.047, 0.031)


def clamp(x, lo=0.0, hi=1.0):
    return lo if x < lo else hi if x > hi else x


def cov(d):
    return clamp(0.5 - d)


def smooth(e0, e1, x):
    t = clamp((x - e0) / (e1 - e0))
    return t * t * (3 - 2 * t)


def circle(x, y, cx, cy, r):
    return math.hypot(x - cx, y - cy) - r


def box(x, y, cx, cy, hw, hh, rad=0.0):
    qx, qy = abs(x - cx) - hw + rad, abs(y - cy) - hh + rad
    return math.hypot(max(qx, 0.0), max(qy, 0.0)) + min(max(qx, qy), 0.0) - rad


def rot(x, y, cx, cy, deg):
    a = math.radians(deg)
    dx, dy = x - cx, y - cy
    return cx + dx * math.cos(a) - dy * math.sin(a), cy + dx * math.sin(a) + dy * math.cos(a)


def white(w, h, alpha_at):
    return [[(1.0, 1.0, 1.0, clamp(alpha_at(i + 0.5, j + 0.5))) for i in range(w)] for j in range(h)]


def layers(w, h, stack):
    """Straight-alpha 'over' of (rgb, alpha_at) layers, bottom first."""
    rows = []
    for j in range(h):
        row = []
        for i in range(w):
            r = g = b = a = 0.0
            for rgb, alpha_at in stack:
                sa = clamp(alpha_at(i + 0.5, j + 0.5))
                if sa <= 0.0:
                    continue
                na = sa + a * (1.0 - sa)
                r = (rgb[0] * sa + r * a * (1.0 - sa)) / na
                g = (rgb[1] * sa + g * a * (1.0 - sa)) / na
                b = (rgb[2] * sa + b * a * (1.0 - sa)) / na
                a = na
            row.append((r, g, b, a))
        rows.append(row)
    return rows


def tga(rows):
    h, w = len(rows), len(rows[0])
    assert w & (w - 1) == 0 and h & (h - 1) == 0, "power-of-two sizes only"
    out = bytearray(struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, w, h, 32, 8))
    for row in reversed(rows):
        for r, g, b, a in row:
            out += bytes((int(round(b * 255)), int(round(g * 255)), int(round(r * 255)), int(round(a * 255))))
    return bytes(out)


def png(rows, back=None):
    """RGBA PNG; with `back`, composited on that colour (for previews)."""
    raw = bytearray()
    for row in rows:
        raw.append(0)
        for r, g, b, a in row:
            if back:
                r, g, b, a = r * a + back[0] * (1 - a), g * a + back[1] * (1 - a), b * a + back[2] * (1 - a), 1.0
            raw += bytes((int(round(r * 255)), int(round(g * 255)), int(round(b * 255)), int(round(a * 255))))

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    head = struct.pack(">IIBBBBB", len(rows[0]), len(rows), 8, 6, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", head) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")


# ── the fire ───────────────────────────────────────────────────────────────
def flame_shape(S, phase, scale, lift):
    """Distance to a teardrop of circles along a swaying spine, in a cell of S px. `scale` shrinks the inner
    tongues, `lift` raises their base."""
    base_y, tip_y = S * (0.70 - lift), S * (0.70 - lift) - S * 0.56 * scale * (0.93 + 0.07 * math.sin(phase * 2 + scale * 5))
    R, n = S * 0.205 * scale, max(14, S // 6)  # enough circles for a smooth edge at any size
    pts = []
    for k in range(n + 1):
        u = k / n
        sway = S * 0.055 * scale * (u ** 1.6) * math.sin(phase + u * 2.6 + scale * 3)
        r = R * (1 - u) ** 0.85 * (0.72 + 0.28 * min(1.0, u * 5))
        pts.append((S * 0.5 + sway, base_y + (tip_y - base_y) * u, r))

    def d(x, y):
        best = 1e9
        for cx, cy, r in pts:
            v = math.hypot(x - cx, y - cy) - r
            if v < best:
                best = v
        return best

    return d


def logs_stack(S):
    """Two crossed logs under the flame, with their cut ends."""
    cy = S * 0.80
    out = []
    for deg, shade in ((-11, LOG_DARK), (11, LOG)):
        def body(x, y, deg=deg):
            px, py = rot(x, y, S * 0.5, cy, -deg)
            return cov(box(px, py, S * 0.5, cy, S * 0.33, S * 0.058, S * 0.058))
        out.append((shade, body))
        ex, ey = rot(S * 0.5 + S * 0.27 * (1 if deg > 0 else -1), cy, S * 0.5, cy, deg)
        out.append((LOG_END, lambda x, y, ex=ex, ey=ey: cov(circle(x, y, ex, ey, S * 0.036))))
    return out


def fire_cell(S, phase, colours=FIRE):
    deep, ember, core_colour = colours
    outer, mid, core = flame_shape(S, phase, 1.0, 0.0), flame_shape(S, phase + 0.9, 0.68, -0.035), flame_shape(S, phase + 1.7, 0.38, -0.06)
    sparks = []
    for k in range(3):
        t = (phase / (2 * math.pi) + k / 3.0) % 1.0
        sx = S * (0.5 + 0.16 * math.sin(k * 2.1 + t * 3))
        sy = S * (0.34 - 0.26 * t)
        sparks.append((core_colour, lambda x, y, sx=sx, sy=sy, t=t: cov(circle(x, y, sx, sy, S * 0.012)) * (1 - t) * 0.9))
    return layers(S, S, [
        (deep, lambda x, y: smooth(S * 0.10, 0, outer(x, y)) * 0.35),  # the halo hugging the flame
        (deep, lambda x, y: cov(outer(x, y))),
        (ember, lambda x, y: cov(mid(x, y))),
        (core_colour, lambda x, y: cov(core(x, y))),
    ] + logs_stack(S) + sparks)


def flame_sheet(colours=FIRE):
    cells = [fire_cell(CELL, 2 * math.pi * k / FRAMES, colours) for k in range(FRAMES)]
    return [sum((cell[j] for cell in cells), []) for j in range(CELL)]


def logo(S=64):
    c = S / 2.0
    fire = fire_cell(S, 0.6)
    disc = layers(S, S, [
        (NIGHT, lambda x, y: cov(circle(x, y, c, c, c - 1))),
        ((0.33, 0.17, 0.07), lambda x, y: cov(circle(x, y, c, c, c - 1)) * smooth(c * 0.95, 0, math.hypot(x - c, y - c * 1.1)) * 0.9),
        (EMBER, lambda x, y: cov(abs(circle(x, y, c, c, c - S * 0.04)) - S * 0.019) * 0.9),
    ])
    rows = []
    for j in range(S):
        row = []
        for i in range(S):
            br, bg, bb, ba = disc[j][i]
            fr, fg, fb, fa = fire[j][i]
            a = fa + ba * (1 - fa)
            if a <= 0:
                row.append((0.0, 0.0, 0.0, 0.0))
            else:
                row.append(((fr * fa + br * ba * (1 - fa)) / a, (fg * fa + bg * ba * (1 - fa)) / a, (fb * fa + bb * ba * (1 - fa)) / a, a))
        rows.append(row)
    return rows


# ── light, shapes, paper ───────────────────────────────────────────────────
def glow():
    c = 64.0
    return white(128, 128, lambda x, y: smooth(1.0, 0.0, math.hypot(x - c, y - c) / 63.0))


def ring():
    return white(64, 64, lambda x, y: cov(abs(circle(x, y, 32, 32, 27.5)) - 2.6))


def disc():
    return white(64, 64, lambda x, y: cov(circle(x, y, 32, 32, 30)))


def slot():
    return white(64, 64, lambda x, y: cov(box(x, y, 32, 32, 29, 29, 11)))


def slot_ring():
    return white(64, 64, lambda x, y: cov(abs(box(x, y, 32, 32, 28, 28, 10)) - 1.6))


def slot_dash():
    def a(x, y):
        edge = cov(abs(box(x, y, 32, 32, 27, 27, 10)) - 1.3)
        turn = (math.atan2(y - 32, x - 32) / (2 * math.pi)) % 1.0
        return edge * (1.0 if (turn * 14) % 1.0 < 0.6 else 0.0)
    return white(64, 64, a)


def grain():
    """Tileable paper grain: value noise from a fixed LCG, two octaves."""
    n, seed = 128, [20261111]

    def rnd():
        seed[0] = (seed[0] * 1103515245 + 12345) & 0x7FFFFFFF
        return seed[0] / 0x7FFFFFFF

    def lattice(cells):
        g = [[rnd() for _ in range(cells)] for _ in range(cells)]

        def at(x, y):
            fx, fy = x / n * cells, y / n * cells
            ix, iy = int(fx) % cells, int(fy) % cells
            tx, ty = fx - int(fx), fy - int(fy)
            tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
            a, b = g[iy][ix], g[iy][(ix + 1) % cells]
            c, d = g[(iy + 1) % cells][ix], g[(iy + 1) % cells][(ix + 1) % cells]
            return (a + (b - a) * tx) * (1 - ty) + (c + (d - c) * tx) * ty
        return at

    coarse, fine = lattice(16), lattice(64)
    return white(n, n, lambda x, y: 0.55 * coarse(x, y) + 0.45 * fine(x, y))


def vignette():
    c = 128.0
    return white(256, 256, lambda x, y: smooth(0.45, 1.05, math.hypot((x - c) / c, (y - c) / c)) ** 1.3)


def corner():
    """A small flourish for the window's corners: two strokes meeting in a dot (drawn for the top-left)."""
    def a(x, y):
        strokes = min(box(x, y, 16, 3.5, 12, 1.0, 1.0), box(x, y, 3.5, 16, 1.0, 12, 1.0))
        return max(cov(strokes), cov(circle(x, y, 3.5, 3.5, 2.6)), cov(circle(x, y, 9.5, 9.5, 1.6)))
    return white(32, 32, a)


def crown():
    """The owner's mark: a small flame."""
    shape = flame_shape(32, 0.4, 1.2, -0.12)
    return white(32, 32, lambda x, y: cov(shape(x, y)))


def copies():
    """Another copy of the zone: two stacked sheets."""
    def a(x, y):
        back = abs(box(x, y, 18.5, 13.5, 8.5, 8.5, 3)) - 1.2
        front = box(x, y, 13.5, 18.5, 8.5, 8.5, 3)
        return max(cov(front), cov(max(back, -(front - 2.2))))
    return white(32, 32, a)


TEXTURES = [
    ("flame", flame_sheet), ("flame-violet", lambda: flame_sheet(VIOLET)), ("logo", logo), ("glow", glow), ("ring", ring), ("disc", disc), ("slot", slot),
    ("slot-ring", slot_ring), ("slot-dash", slot_dash), ("grain", grain), ("vignette", vignette),
    ("corner", corner), ("crown", crown), ("copies", copies),
]


def main(argv):
    check = "--check" in argv
    preview = argv[argv.index("--preview") + 1] if "--preview" in argv else None
    os.makedirs(MEDIA, exist_ok=True)
    stale = []
    for name, draw in TEXTURES:
        rows = draw()
        data = tga(rows)
        path = os.path.join(MEDIA, name + ".tga")
        if check:
            try:
                with open(path, "rb") as f:
                    if f.read() != data:
                        stale.append(name)
            except OSError:
                stale.append(name)
            continue
        with open(path, "wb") as f:
            f.write(data)
        if preview:
            os.makedirs(preview, exist_ok=True)
            with open(os.path.join(preview, name + ".png"), "wb") as f:
                f.write(png(rows, back=(0.14, 0.086, 0.05)))
    if check:
        if stale:
            sys.stderr.write("gen-media: out of date: %s\n" % ", ".join(stale))
            return 1
        print("gen-media: %d textures up to date" % len(TEXTURES))
        return 0
    with open(os.path.join(MEDIA, "logo-512.png"), "wb") as f:
        f.write(png(logo(512)))
    print("gen-media: wrote %d textures to Media/" % len(TEXTURES))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
