"""Krajiny kapitol II–IV: Skalní les, sopka (Voda a oheň) a Bouřková hora.

Každé téma má stejné vrstvy jako louka kapitoly I (nebe se sluncem, mraky
a ptáci jako výřezy, hory, střední pás, blízký pás) ve složce layers/<téma>/,
se stejnými rozměry a kotvami, takže je PaperWorld jen vymění. Louka zůstává
beze změny v build_backgrounds.py. Generátor je deterministický (pevné seedy).
"""

from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np

from build_backgrounds import TILE, mountain, pine, soften
from paperlib import Canvas, ellipse, fiber_field, mix, rgb, tear, transform

THEMES = ("les", "sopka", "bourka")

# Barvy témat (vzorkované z papírových odstínů louky a posunuté k náladě kapitoly).
PAL = {
    "les": {
        "cloud": "#eef0e8", "cloud_shade": "#cfd8d0", "sun": "#f3d68e", "sun_light": "#f8e3aa",
        "bird": "#8a4a2e", "bird_light": "#a85f3a",
        "far_lit": "#c8d4cd", "far_shade": "#a3b5b1", "lit": "#b3c1ba", "shade": "#879a96",
        "low": "#6f8f86", "low_shade": "#5c7c74", "snow": "#eef0e8", "snow_shade": "#d0dcdc",
        "haze": "#86a39a", "haze_low": "#6c8b82",
        "hills": ["#6f9488", "#5d8576", "#4f7768"], "pine_far": "#5b8378", "pine_far_shade": "#4b7066",
        "pine_mid": "#3f6b5f", "pine_mid_shade": "#30584d", "pine_near": "#26514a",
        "pine_near_shade": "#1b403a", "pine_deep": "#163a35", "pine_deep_shade": "#0f2e2a",
        "rock": "#c2bba6", "rock_shade": "#99927f", "rock_dark": "#7c7667", "moss": "#7f9a58",
        "moss_light": "#98b067", "ground": "#41604f", "trunk": "#5e4330",
    },
    "sopka": {
        "cloud": "#d9c4b6", "cloud_shade": "#aa958b", "sun": "#f29a5c", "sun_light": "#f7bd7e",
        "bird": "#3a2d2e", "bird_light": "#4f3e3e",
        "far_lit": "#a8929a", "far_shade": "#867079", "lit": "#8a7680", "shade": "#655460",
        "low": "#5a4b55", "low_shade": "#463944", "snow": "#d8c8c0", "snow_shade": "#b8a8a4",
        "haze": "#a07a78", "haze_low": "#7d6064",
        "cone": "#6c5a60", "cone_shade": "#4f4148", "lava": "#e5622b", "lava_light": "#f7a04a",
        "glow": "#f58a3c", "smoke": "#8e817d", "smoke_shade": "#6f625f",
        "hills": ["#7a6567", "#665458", "#55454b"], "char": "#3a2f33", "char_shade": "#2a2226",
        "pine_near": "#2f3a35", "pine_near_shade": "#222b27",
        "rock": "#4a3e43", "rock_shade": "#342b30", "rock_dark": "#251e22",
        "water": "#86728a", "water_deep": "#5d4b62", "water_light": "#f2a56a", "ground": "#3e3237",
    },
    "bourka": {
        "cloud": "#a7afb4", "cloud_shade": "#7d878e", "storm": "#6b7680", "storm_shade": "#58626c",
        "far_lit": "#bcc6cb", "far_shade": "#8f9da6", "lit": "#a9b5bc", "shade": "#6f808b",
        "low": "#5f727b", "low_shade": "#4d5f68", "snow": "#eef1f0", "snow_shade": "#c9d3d8",
        "haze": "#7e8f96", "haze_low": "#5f7179",
        "hills": ["#62757b", "#536770", "#465b63"], "pine_far": "#4f656b", "pine_far_shade": "#41565c",
        "pine_mid": "#334c4f", "pine_mid_shade": "#273e41", "pine_near": "#20393a",
        "pine_near_shade": "#172d2e", "rock": "#8a9396", "rock_shade": "#687276", "ground": "#34474d",
        "trunk": "#4a3a30", "hut": "#a27c5a", "hut_shade": "#81603f", "hut_roof": "#5b4a44",
        "window": "#f3cf7a",
    },
}

# Hloubka ostrosti jako u louky (sigma v pixelech textury).
DEPTH_BLUR = {"sky_decor": 1.4, "mountains": 3.2, "midground": 2.2, "near": 1.2,
              "cloud_0": 1.4, "cloud_1": 1.4, "cloud_2": 1.4, "cloud_3": 1.4, "cloud_4": 1.4,
              "bird_0": 1.0, "bird_1": 1.0, "bird_2": 1.0}
WRAPPED = {"sky_decor", "mountains", "midground", "near"}


def soft_glow(c, cx, cy, rx, ry, color, strength):
    """Měkká záře (gaussovská průsvitnost) – světlo, ne vystřižený papír."""
    x0, y0 = int(cx - rx * 2), int(cy - ry * 2)
    w, h = int(rx * 4), int(ry * 4)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    d = ((xx + x0 - cx) / rx) ** 2 + ((yy + y0 - cy) / ry) ** 2
    c.over(rgb(color), np.exp(-d * 1.6).astype(np.float32) * strength, x0, y0)


def cloud_shape(c, cx, cy, w, h, rng, col, shade):
    """Kupovitý mrak z laloků se stínovou vrstvou (jako na louce, jiné barvy)."""
    lobes = []
    n = max(4, int(w / 70))
    for i in range(n):
        t = (i + 0.5) / n
        r = h * (0.32 + 0.55 * math.sin(math.pi * t) ** 1.3) * rng.uniform(0.85, 1.12)
        lobes.append((cx - w / 2 + w * t, cy - r * 0.55, r))
    for i in range(n - 1):
        t = (i + 1.0) / n
        r = h * (0.45 + 0.5 * math.sin(math.pi * t)) * rng.uniform(0.8, 1.0)
        lobes.append((cx - w / 2 + w * t, cy - r * 0.95, r * 0.8))
    base = [(cx - w / 2 - h * 0.2, cy), (cx + w / 2 + h * 0.2, cy),
            (cx + w / 2 + h * 0.1, cy - h * 0.25), (cx - w / 2 - h * 0.1, cy - h * 0.25)]
    for layer, (dx, dy, color) in enumerate([(16, 12, shade), (0, 0, col)]):
        polys = [tear(transform(ellipse(x, y, r, r, 40), dx, dy), 1.4, rng, step=4) for x, y, r in lobes]
        polys.append(transform(base, dx, dy))
        polys = [[(px, min(py, cy + dy)) for px, py in poly] for poly in polys]
        c.shape(polys, color, fiber=0.05, shadow=(8, 10, 7, 0.10) if layer == 0 else None,
                core=(3.0, 0.5) if layer == 1 else None)
    c.crease((cx - w * 0.3, cy - h * 0.18), (cx + w * 0.25, cy - h * 0.15), 3, shade, 0.35)


def bird_shape(c, bx, by, size, wing, col, light):
    body = [(bx - size * 0.5, by + size * 0.1), (bx + size * 0.7, by - size * 0.05),
            (bx + size * 0.2, by + size * 0.3)]
    back = [(bx, by), (bx - size * 0.95, by - size * 0.75 * wing), (bx - size * 0.35, by + size * 0.15)]
    front = [(bx, by), (bx + size * 0.85, by - size * 0.5 * wing), (bx + size * 0.3, by + size * 0.2)]
    c.shape(back, mix(col, "#000000", 0.12), fiber=0.05)
    c.shape(body, col, fiber=0.05, shadow=(3, 4, 3, 0.12))
    c.shape(front, light, fiber=0.05)


def sky_cutouts(theme, fiber, rng, out: Path, p, sizes, speeds, birds=True) -> dict:
    """Mraky (a ptáci) jako samostatné výřezy; vrací popis pro sky.json."""
    folder = out / "layers" / theme
    clouds = []
    for i, (x, y, w, h) in enumerate(sizes):
        cw, ch = int(w + h * 0.6 + 70), int(h * 1.45 + 50)
        cloud = Canvas(cw, ch, fiber=fiber)
        ax, ay = cw / 2 - 8, ch - 34
        cloud_shape(cloud, ax, ay, w, h, rng, p["cloud"], p["cloud_shade"])
        cloud.save(folder / f"cloud_{i}.png")
        clouds.append({"texture": f"layers/{theme}/cloud_{i}.png", "pos": [x, y], "anchor": [ax, ay],
                       "speed": speeds[i]})
    data = {"tile": TILE, "clouds": clouds}
    if birds:
        frames = []
        for k, wing in enumerate([1.0, 0.25, -0.6]):
            bird = Canvas(84, 70, fiber=fiber)
            bird_shape(bird, 40, 36, 26, wing, p["bird"], p["bird_light"])
            bird.save(folder / f"bird_{k}.png")
            frames.append(f"layers/{theme}/bird_{k}.png")
        data["birds"] = {"frames": frames, "anchor": [40, 36],
                         "flock": [[0, 0, 1.0], [-70, 38, 0.8], [-130, 12, 0.7]],
                         "start": [1250, 140], "speed": 2.6}
    return data


def mountain_rows(c, rng, p, base, rows, snow=True):
    """Řady hor zezadu dopředu: (počet, výška od–do, šířka od–do, světlo, stín, sníh, stín pod)."""
    for row, (count, hmin, hmax, wmin, wmax, lit, shade, snow_t, shadow_op) in enumerate(rows):
        for x in np.sort(rng.uniform(0, TILE, count)):
            height = rng.uniform(hmin, hmax)
            half = rng.uniform(wmin, wmax)
            pts, sh, peak = mountain(x, base + row * 30, height, half, rng, rng.uniform(-0.25, 0.25))
            pts = tear(pts, 2.0, rng, step=4)
            c.shape(pts, lit, fiber=0.07, shadow=(5, 6, 5, shadow_op))
            c.shape(tear(sh, 1.6, rng, step=4), shade, fiber=0.07)
            left_base = (pts[0][0] + half * rng.uniform(0.25, 0.6), base + row * 30)
            facet = [peak, left_base, (peak[0] - half * rng.uniform(0.15, 0.35), peak[1] + height * 0.55)]
            c.shape(facet, mix(lit, shade, 0.35), fiber=0.07)
            if snow and snow_t > 0.0 and height > 300 - row * 60:
                cap_h = height * rng.uniform(0.18, 0.3)
                left_x = peak[0] - cap_h * (half / height) * 1.05
                right_x = peak[0] + cap_h * (half / height) * 1.05
                cap = [peak, (right_x, peak[1] + cap_h)]
                for i in range(1, 7):
                    t = i / 7
                    cap.append((right_x + (left_x - right_x) * t,
                                peak[1] + cap_h * (0.62 if i % 2 else 1.0) + rng.uniform(-6, 6)))
                cap.append((left_x, peak[1] + cap_h))
                cap_poly = tear(cap, 1.2, rng, step=3)
                c.shape(cap_poly, mix(p["snow"], lit, 1 - snow_t), fiber=0.05)
                ridge = [peak, (peak[0] + cap_h * 0.3, peak[1] + cap_h * 0.95), (right_x, peak[1] + cap_h)]
                c.shape(ridge + [(peak[0] + 2, peak[1] + 4)], mix(p["snow_shade"], shade, 0.3), fiber=0.05)
                c.core(cap_poly, 2.0, 0.35)
            c.core(pts, 3.0, 0.5)


def haze_band(c, p, base, h):
    c.shape([(0, base - 70), (TILE, base - 70), (TILE, h), (0, h)], p["haze"], fiber=0.04,
            gradient=(p["haze_low"], base - 70, h))


def hill_rows(c, rng, colors, bases, h, amp=60):
    for k, (y_base, col) in enumerate(zip(bases, colors)):
        pts = [(-40, h)]
        for i in range(0, 61):
            x = -40 + i * (TILE + 80) / 60
            pts.append((x, y_base - amp * math.sin(i * 0.37 + k * 1.7) - amp * 0.66 * math.sin(i * 0.11 + k)))
        pts.append((TILE + 40, h))
        c.shape(tear(pts, 2.5, rng, step=6, closed=True), col, fiber=0.06, shadow=(5, 8, 7, 0.14),
                core=(3.5, 0.45))


def hill_y(x, y_base, k, amp=60):
    i = (x + 40) / ((TILE + 80) / 60)
    return y_base - amp * math.sin(i * 0.37 + k * 1.7) - amp * 0.66 * math.sin(i * 0.11 + k)


def pine_rows(c, rng, rows, lean=0.0, skip=None, trunk=None):
    for row, (count, hmin, hmax, ybase, col, shade, shadow) in enumerate(rows):
        for x in np.sort(rng.uniform(0, TILE, count)):
            if skip is not None and skip(row, x):
                continue
            yb = ybase(x) if callable(ybase) else ybase + 25 * math.sin(x * 0.004 + row) + rng.uniform(-10, 10)
            hh = rng.uniform(hmin, hmax)
            tilt = lean * rng.uniform(0.7, 1.2)
            full, sh, tr = pine(x, yb, hh, hh * 0.45, 5 if hh < 200 else 6, rng, lean=tilt)
            if trunk is not None and hh > 140:
                c.shape(tr, trunk, fiber=0.05)
            torn = tear(full, 1.4, rng, step=4)
            c.shape(torn, col, fiber=0.07, shadow=shadow)
            c.shape(sh, shade, fiber=0.07)
            c.core(torn, 1.8, 0.4)


def boulder(c, cx, base, w, h, rng, col, shade, moss=None):
    pts = []
    for k in range(13):
        a = math.pi + k * math.pi / 12
        r = rng.uniform(0.85, 1.05)
        pts.append((cx + math.cos(a) * w / 2 * r, base + math.sin(a) * h * r))
    pts += [(cx + w / 2, base + 6), (cx - w / 2, base + 6)]
    poly = tear(pts, 2.0, rng, step=4)
    c.shape(poly, col, fiber=0.08, shadow=(5, 7, 6, 0.22), core=(2.5, 0.4))
    c.shape(tear([(cx + w * 0.05, base - h * 0.95), (cx + w / 2, base - h * 0.2), (cx + w / 2, base + 6),
                  (cx + w * 0.12, base + 6)], 1.5, rng, step=4), shade, fiber=0.08)
    if moss is not None:
        cap = [(cx - w * 0.42, base - h * 0.55), (cx - w * 0.1, base - h * 1.02), (cx + w * 0.3, base - h * 0.85),
               (cx + w * 0.1, base - h * 0.7), (cx - w * 0.25, base - h * 0.5)]
        c.shape(tear(cap, 1.5, rng, step=3), moss, fiber=0.06)


def rock_tower(c, cx, base, w, hgt, rng, p):
    """Pískovcová věž „skalního města“: zaoblená hlava, svislé pukliny, stínovaná pravá strana."""
    pts = [(cx - w / 2, base)]
    for i in range(1, 6):
        t = i / 6
        pts.append((cx - w / 2 + rng.uniform(-6, 6) + w * 0.06 * math.sin(t * 7), base - hgt * t * 0.82))
    for k in range(9):
        a = math.pi + k * math.pi / 8
        pts.append((cx + math.cos(a) * w * 0.52, base - hgt * 0.82 + math.sin(a) * hgt * 0.18))
    for i in range(5, 0, -1):
        t = i / 6
        pts.append((cx + w / 2 + rng.uniform(-6, 6) - w * 0.05 * math.sin(t * 5), base - hgt * t * 0.82))
    pts.append((cx + w / 2, base))
    poly = tear(pts, 2.2, rng, step=4)
    c.shape(poly, p["rock"], fiber=0.08, shadow=(6, 8, 6, 0.2), core=(3.0, 0.45))
    c.shape(tear([(cx + w * 0.12, base - hgt), (cx + w * 0.55, base - hgt * 0.75), (cx + w * 0.5, base),
                  (cx + w * 0.2, base)], 1.6, rng, step=4), p["rock_shade"], fiber=0.08)
    for k in range(3):
        x = cx - w * 0.3 + k * w * 0.22 + rng.uniform(-4, 4)
        c.crease((x, base - hgt * rng.uniform(0.5, 0.75)), (x + rng.uniform(-6, 6), base - 10), 2.5,
                 p["rock_dark"], 0.45)
    # Vodorovné vrstvy pískovce.
    for k in range(4):
        y = base - hgt * (0.15 + k * 0.17) + rng.uniform(-5, 5)
        c.crease((cx - w * 0.48, y), (cx + w * 0.46, y + rng.uniform(-4, 4)), 2.0, p["rock_dark"], 0.3)
    # Malá jedle na temeni.
    full, sh, tr = pine(cx + rng.uniform(-w * 0.15, w * 0.15), base - hgt * 0.97, hgt * 0.32, hgt * 0.14, 4, rng)
    c.shape(full, p["pine_mid"], fiber=0.06)
    c.shape(sh, p["pine_mid_shade"], fiber=0.06)


def charred_tree(c, x, base, hgt, rng, p):
    """Ohořelý strom: tmavý kmen a pár holých větví."""
    w = hgt * 0.06
    c.shape([(x - w, base), (x - w * 0.5, base - hgt), (x + w * 0.5, base - hgt), (x + w, base)],
            p["char"], fiber=0.05, shadow=(3, 4, 3, 0.15))
    for k in range(4):
        y = base - hgt * rng.uniform(0.35, 0.9)
        side = -1 if k % 2 else 1
        length = hgt * rng.uniform(0.18, 0.32)
        tip = (x + side * length, y - length * rng.uniform(0.4, 0.8))
        c.shape([(x, y), tip, (x, y - w * 1.6)], p["char_shade"], fiber=0.04)


# --- Skalní les ------------------------------------------------------------------

def les(fiber, out: Path, seed: int) -> dict:
    p = PAL["les"]
    rng = np.random.default_rng(seed)
    c = Canvas(TILE, 560, wrap_x=True, fiber=fiber)
    sun = tear(ellipse(1960, 170, 64, 64, 90), 2.2, rng, step=3)
    c.shape(sun, p["sun"], fiber=0.08, shadow=(4, 5, 4, 0.10), rim=(2, p["sun_light"], 0.5))
    c.core(sun, 3.0, 0.5)
    c.save(out / "layers" / "les" / "sky_decor.png")
    sky = sky_cutouts("les", fiber, rng, out, p,
                      [(300, 280, 320, 110), (900, 210, 210, 70), (1450, 320, 260, 86), (2150, 260, 300, 100),
                       (2600, 190, 180, 62)], [0.14, 0.2, 0.1, 0.18, 0.24])

    rng = np.random.default_rng(seed + 1)
    h = 640
    c = Canvas(TILE, h, wrap_x=True, fiber=fiber)
    base = h - 40
    mountain_rows(c, rng, p, base, [
        (10, 280, 440, 200, 340, p["far_lit"], p["far_shade"], 0.45, 0.07),
        (9, 220, 380, 180, 300, p["lit"], p["shade"], 0.3, 0.12),
        (11, 130, 230, 160, 260, p["low"], p["low_shade"], 0.0, 0.14),
    ])
    haze_band(c, p, base, h)
    c.save(out / "layers" / "les" / "mountains.png")

    rng = np.random.default_rng(seed + 2)
    h = 720
    c = Canvas(TILE, h, wrap_x=True, fiber=fiber)
    bases = [330, 400, 470]
    hill_rows(c, rng, p["hills"], bases, h)
    for x in np.sort(rng.uniform(0, TILE, 90)):
        yb = hill_y(x, bases[0], 0) + 30
        hh = rng.uniform(50, 95)
        full, sh, _ = pine(x, yb, hh, hh * 0.42, 4, rng)
        c.shape(full, p["pine_far"], fiber=0.06)
        c.shape(sh, p["pine_far_shade"], fiber=0.06)
    towers = [(380, 3), (1150, 4), (1900, 3), (2500, 2)]
    for tx, n in towers:
        for k in range(n):
            w = rng.uniform(70, 110)
            hgt = rng.uniform(170, 280)
            rock_tower(c, tx + k * rng.uniform(70, 95), 560 + rng.uniform(-10, 14), w, hgt, rng, p)
    pine_rows(c, rng, [
        (100, 70, 125, 540, p["pine_mid"], p["pine_mid_shade"], (3, 5, 4, 0.16)),
        (80, 95, 160, 615, mix(p["pine_mid"], p["pine_near"], 0.4), mix(p["pine_mid_shade"], p["pine_near_shade"], 0.4),
         (3, 5, 4, 0.16)),
    ])
    bottom = [(-20, 650)] + [(-20 + i * (TILE + 40) / 40, 645 - 16 * math.sin(i * 0.8) + rng.uniform(-6, 6))
                             for i in range(41)] + [(TILE + 20, h + 5), (-20, h + 5)]
    c.shape(bottom, p["ground"], fiber=0.05)
    c.save(out / "layers" / "les" / "midground.png")

    rng = np.random.default_rng(seed + 3)
    h = 620
    c = Canvas(TILE, h, wrap_x=True, fiber=fiber)
    c.shape([(-20, 470), (TILE + 20, 470), (TILE + 20, h + 5), (-20, h + 5)], p["ground"], fiber=0.06,
            gradient=(mix(p["ground"], "#000000", 0.25), 470, h))
    for x in np.sort(rng.uniform(0, TILE, 14)):
        boulder(c, x, 500 + rng.uniform(-10, 20), rng.uniform(90, 170), rng.uniform(50, 90), rng,
                p["rock"], p["rock_shade"], p["moss"])
    pine_rows(c, rng, [
        (40, 170, 270, 450, p["pine_near"], p["pine_near_shade"], (6, 9, 7, 0.26)),
        (26, 230, 350, 480, p["pine_deep"], p["pine_deep_shade"], (6, 9, 7, 0.26)),
    ], trunk=p["trunk"])
    c.save(out / "layers" / "les" / "near.png")
    return sky


# --- Sopka -----------------------------------------------------------------------

def volcano(c, cx, base, half, height, rng, p):
    top_w = half * 0.22
    pts = [(cx - half, base)]
    for i in range(1, 8):
        t = i / 8
        pts.append((cx - half + (half - top_w) * t, base - height * (t ** 0.8) + rng.uniform(-8, 8)))
    pts += [(cx - top_w, base - height), (cx - top_w * 0.4, base - height + 18), (cx + top_w * 0.4, base - height + 14),
            (cx + top_w, base - height)]
    for i in range(1, 8):
        t = 1 - i / 8
        pts.append((cx + half - (half - top_w) * t, base - height * (t ** 0.8) + rng.uniform(-8, 8)))
    pts.append((cx + half, base))
    poly = tear(pts, 2.2, rng, step=4)
    # Záře nad kráterem: měkké světlo, ne vystřižený kotouč.
    soft_glow(c, cx, base - height, top_w * 2.0, top_w * 1.1, p["glow"], 0.55)
    c.shape(poly, p["cone"], fiber=0.08, shadow=(6, 8, 6, 0.18), core=(3.0, 0.45))
    c.shape(tear([(cx + top_w * 0.2, base - height), (cx + top_w, base - height), (cx + half, base),
                  (cx + half * 0.25, base)], 1.8, rng, step=4), p["cone_shade"], fiber=0.08)
    # Lávové stružky po svahu.
    for k in range(3):
        x0 = cx + rng.uniform(-top_w * 0.8, top_w * 0.8)
        y0 = base - height + 12
        pts_l, pts_r = [], []
        x, y = x0, y0
        steps = int(rng.uniform(6, 11))
        drift = rng.uniform(-0.35, 0.35)
        for s in range(steps):
            w = 10 * (1 - s / steps) + 3
            pts_l.append((x - w, y))
            pts_r.append((x + w, y))
            x += drift * 40 + rng.uniform(-10, 10)
            y += height / 12
        color = p["lava"] if k % 2 else p["lava_light"]
        c.shape(pts_l + list(reversed(pts_r)), color, fiber=0.03)
    # Kouřový sloup z kupovitých obláčků, unášený doprava.
    for k in range(7):
        r = 26 + k * 11
        sx = cx + k * k * 7 + rng.uniform(-8, 8)
        sy = base - height - 20 - k * 34
        if sy - r < 4:
            break
        col = p["smoke"] if k % 2 == 0 else p["smoke_shade"]
        c.shape(tear(ellipse(sx, sy, r * 1.25, r, 36), 2.0, rng, step=4), col, fiber=0.05,
                shadow=(4, 6, 6, 0.12), core=(2.5, 0.35))


def sopka(fiber, out: Path, seed: int) -> dict:
    p = PAL["sopka"]
    rng = np.random.default_rng(seed)
    c = Canvas(TILE, 560, wrap_x=True, fiber=fiber)
    sun = tear(ellipse(520, 420, 96, 96, 90), 2.4, rng, step=3)
    c.shape(sun, p["sun"], fiber=0.06, rim=(3, p["sun_light"], 0.45))
    c.core(sun, 3.0, 0.45)
    c.save(out / "layers" / "sopka" / "sky_decor.png")
    sky = sky_cutouts("sopka", fiber, rng, out, p,
                      [(350, 240, 340, 96), (1000, 170, 220, 66), (1500, 290, 280, 84), (2200, 220, 320, 92),
                       (2650, 150, 200, 60)], [0.1, 0.16, 0.08, 0.14, 0.2])

    rng = np.random.default_rng(seed + 1)
    h = 640
    c = Canvas(TILE, h, wrap_x=True, fiber=fiber)
    base = h - 40
    mountain_rows(c, rng, p, base, [
        (8, 220, 360, 240, 380, p["far_lit"], p["far_shade"], 0.0, 0.07),
    ], snow=False)
    volcano(c, 1400, base + 10, 480, 330, rng, p)
    volcano(c, 2550, base + 20, 280, 200, rng, p)
    mountain_rows(c, rng, p, base + 30, [
        (10, 120, 210, 170, 280, p["low"], p["low_shade"], 0.0, 0.14),
    ], snow=False)
    haze_band(c, p, base, h)
    c.save(out / "layers" / "sopka" / "mountains.png")

    rng = np.random.default_rng(seed + 2)
    h = 720
    c = Canvas(TILE, h, wrap_x=True, fiber=fiber)
    bases = [340, 420, 500]
    hill_rows(c, rng, p["hills"], bases, h, amp=50)
    # Žhnoucí pukliny na svazích.
    for x in np.sort(rng.uniform(0, TILE, 18)):
        y = hill_y(x, bases[1], 1, 50) + rng.uniform(20, 70)
        length = rng.uniform(40, 110)
        crack = [(x, y), (x + length * 0.4, y + 6), (x + length, y + 2), (x + length * 0.55, y + 10),
                 (x + length * 0.1, y + 8)]
        c.shape(tear(crack, 1.2, rng, step=3), p["lava"], fiber=0.03, rim=(3, p["glow"], 0.35))
    for x in np.sort(rng.uniform(0, TILE, 45)):
        charred_tree(c, x, hill_y(x, bases[2], 2, 50) + rng.uniform(20, 60), rng.uniform(60, 120), rng, p)
    bottom = [(-20, 650)] + [(-20 + i * (TILE + 40) / 40, 640 - 14 * math.sin(i * 0.7) + rng.uniform(-6, 6))
                             for i in range(41)] + [(TILE + 20, h + 5), (-20, h + 5)]
    c.shape(bottom, p["ground"], fiber=0.05)
    c.save(out / "layers" / "sopka" / "midground.png")

    rng = np.random.default_rng(seed + 3)
    h = 620
    c = Canvas(TILE, h, wrap_x=True, fiber=fiber)
    # Jezero s odlesky žhnoucího nebe.
    c.shape([(-20, 430), (TILE + 20, 430), (TILE + 20, h + 5), (-20, h + 5)], p["water"], fiber=0.05,
            gradient=(p["water_deep"], 430, h))
    for _ in range(80):
        x = rng.uniform(0, TILE)
        y = rng.uniform(450, h - 10)
        w = rng.uniform(30, 120)
        c.shape(tear([(x, y), (x + w, y - 2), (x + w * 0.9, y + 3), (x + 4, y + 4)], 0.6, rng, step=4),
                p["water_light"], fiber=0.02)
    for x in np.sort(rng.uniform(0, TILE, 16)):
        boulder(c, x, 470 + rng.uniform(-10, 30), rng.uniform(120, 220), rng.uniform(60, 120), rng,
                p["rock"], p["rock_shade"])
    pine_rows(c, rng, [
        (18, 160, 250, 450, p["pine_near"], p["pine_near_shade"], (6, 9, 7, 0.26)),
    ], skip=lambda row, x: 1000 < x < 1800)
    for x in np.sort(rng.uniform(1000, 1800, 5)):
        charred_tree(c, x, 470 + rng.uniform(0, 20), rng.uniform(160, 240), rng, p)
    c.save(out / "layers" / "sopka" / "near.png")
    return sky


# --- Bouřková hora -----------------------------------------------------------------

def hut(c, x, base, w, hgt, p):
    c.shape([(x, base), (x, base - hgt), (x + w, base - hgt), (x + w, base)], p["hut"], fiber=0.06,
            shadow=(3, 3, 2, 0.15))
    c.shape([(x + w * 0.6, base), (x + w * 0.6, base - hgt), (x + w, base - hgt), (x + w, base)],
            p["hut_shade"], fiber=0.06)
    c.shape([(x - w * 0.12, base - hgt + 2), (x + w * 0.5, base - hgt * 1.75), (x + w * 1.12, base - hgt + 2)],
            p["hut_roof"], fiber=0.07, shadow=(2, 3, 2, 0.15))
    c.shape([(x + w * 0.2, base - hgt * 0.65), (x + w * 0.42, base - hgt * 0.65), (x + w * 0.42, base - hgt * 0.4),
             (x + w * 0.2, base - hgt * 0.4)], p["window"], fiber=0.02)


def bourka(fiber, out: Path, seed: int) -> dict:
    p = PAL["bourka"]
    rng = np.random.default_rng(seed)
    c = Canvas(TILE, 560, wrap_x=True, fiber=fiber)
    # Těžký pás bouřkových mraků u horního okraje (slunce za nimi není vidět).
    for k in range(18):
        x = k * TILE / 18 + rng.uniform(-40, 40)
        y = rng.uniform(40, 150)
        w = rng.uniform(260, 420)
        cloud_shape(c, x, y + 60, w, rng.uniform(70, 110), rng, p["storm"], p["storm_shade"])
    c.save(out / "layers" / "bourka" / "sky_decor.png")
    sky = sky_cutouts("bourka", fiber, rng, out, p,
                      [(300, 300, 380, 120), (950, 230, 260, 84), (1500, 340, 320, 100), (2150, 270, 360, 112),
                       (2620, 200, 230, 72)], [0.4, 0.55, 0.32, 0.48, 0.6], birds=False)

    rng = np.random.default_rng(seed + 1)
    h = 640
    c = Canvas(TILE, h, wrap_x=True, fiber=fiber)
    base = h - 40
    mountain_rows(c, rng, p, base, [
        (11, 340, 520, 180, 300, p["far_lit"], p["far_shade"], 0.95, 0.07),
        (10, 260, 440, 160, 270, p["lit"], p["shade"], 0.8, 0.12),
        (12, 140, 240, 150, 240, p["low"], p["low_shade"], 0.3, 0.14),
    ])
    haze_band(c, p, base, h)
    c.save(out / "layers" / "bourka" / "mountains.png")

    rng = np.random.default_rng(seed + 2)
    h = 720
    c = Canvas(TILE, h, wrap_x=True, fiber=fiber)
    bases = [330, 410, 490]
    hill_rows(c, rng, p["hills"], bases, h, amp=70)
    for x in np.sort(rng.uniform(0, TILE, 80)):
        yb = hill_y(x, bases[0], 0, 70) + 30
        hh = rng.uniform(50, 90)
        full, sh, _ = pine(x, yb, hh, hh * 0.4, 4, rng, lean=0.18)
        c.shape(full, p["pine_far"], fiber=0.06)
        c.shape(sh, p["pine_far_shade"], fiber=0.06)
    hut(c, 1180, hill_y(1180, bases[1], 1, 70) + 40, 80, 56, p)
    hut(c, 2380, hill_y(2380, bases[1], 1, 70) + 46, 64, 46, p)
    pine_rows(c, rng, [
        (85, 70, 125, lambda x: hill_y(x, bases[1], 1, 70) + 70, p["pine_mid"], p["pine_mid_shade"],
         (3, 5, 4, 0.16)),
        (70, 95, 160, 615, mix(p["pine_mid"], p["pine_near"], 0.4), mix(p["pine_mid_shade"], p["pine_near_shade"], 0.4),
         (3, 5, 4, 0.16)),
    ], lean=0.22, skip=lambda row, x: row == 0 and (1120 < x < 1300 or 2330 < x < 2470))
    bottom = [(-20, 650)] + [(-20 + i * (TILE + 40) / 40, 645 - 16 * math.sin(i * 0.8) + rng.uniform(-6, 6))
                             for i in range(41)] + [(TILE + 20, h + 5), (-20, h + 5)]
    c.shape(bottom, p["ground"], fiber=0.05)
    c.save(out / "layers" / "bourka" / "midground.png")

    rng = np.random.default_rng(seed + 3)
    h = 620
    c = Canvas(TILE, h, wrap_x=True, fiber=fiber)
    c.shape([(-20, 470), (TILE + 20, 470), (TILE + 20, h + 5), (-20, h + 5)], p["ground"], fiber=0.06,
            gradient=(mix(p["ground"], "#000000", 0.3), 470, h))
    for x in np.sort(rng.uniform(0, TILE, 12)):
        boulder(c, x, 500 + rng.uniform(-10, 20), rng.uniform(90, 170), rng.uniform(50, 90), rng,
                p["rock"], p["rock_shade"])
    pine_rows(c, rng, [
        (34, 170, 270, 450, p["pine_near"], p["pine_near_shade"], (6, 9, 7, 0.26)),
        (20, 230, 340, 480, mix(p["pine_near"], "#000000", 0.25), mix(p["pine_near_shade"], "#000000", 0.25),
         (6, 9, 7, 0.26)),
    ], lean=0.28, trunk=p["trunk"])
    c.save(out / "layers" / "bourka" / "near.png")
    return sky


def build(out: Path, seed: int = 4026) -> None:
    fiber = fiber_field(512, 512, np.random.default_rng(seed))
    for k, (theme, make) in enumerate([("les", les), ("sopka", sopka), ("bourka", bourka)]):
        folder = out / "layers" / theme
        folder.mkdir(parents=True, exist_ok=True)
        sky = make(fiber, out, seed + 100 * (k + 1))
        (folder / "sky.json").write_text(json.dumps(sky, indent=1) + "\n")
        for name, sigma in DEPTH_BLUR.items():
            path = folder / f"{name}.png"
            if path.exists():
                soften(path, sigma, name in WRAPPED)


if __name__ == "__main__":
    build(Path(__file__).resolve().parents[1])
