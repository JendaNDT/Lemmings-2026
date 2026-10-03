"""Paralaxní vrstvy krajiny: nebe, hory, střední pás s vesnicí, blízký les, popředí.

Každá vrstva je vodorovně navazující dlaždice (šířka TILE) s průhledným horním
okrajem. Spodní řádek vrstev je neprůhledný, aby šel v Godotu prodloužit dolů
bez prázdných okrajů. Popředí jsou samostatné trsy rostlin.
"""

from __future__ import annotations

import math
from pathlib import Path

import numpy as np

import palette as P
from paperlib import Canvas, ellipse, fiber_field, mix, rgb, tear, transform

TILE = 2800


def pine(cx, base, height, width, tiers=4, rng=None, lean=0.0):
    """Stupňovitá jedle z vystřiženého papíru: celý obrys a stínovaná pravá půlka."""
    top = base - height
    left, right = [], []
    for i in range(tiers):
        t = (i + 1) / tiers
        y = top + height * t * 0.92
        w = width * (0.28 + 0.72 * t) / 2
        jitter = rng.uniform(-0.06, 0.06) * width if rng is not None else 0
        notch_y = y - height * 0.08
        left += [(cx - w + jitter + lean * (y - base), y), (cx - w * 0.45 + lean * (notch_y - base), notch_y)]
        right += [(cx + w + jitter + lean * (y - base), y), (cx + w * 0.45 + lean * (notch_y - base), notch_y)]
    left = left[:-1]
    right = right[:-1]
    tip = (cx + lean * (top - base), top)
    trunk = [(cx - width * 0.05, base - height * 0.1), (cx + width * 0.05, base - height * 0.1),
             (cx + width * 0.05, base), (cx - width * 0.05, base)]
    full = [tip] + right + [(cx, base - height * 0.06)] + list(reversed(left))
    shade = [tip] + right + [(cx, base - height * 0.06)]
    return full, shade, trunk


def mountain(cx, base, height, half_w, rng, skew=0.0):
    peak = (cx + skew * half_w, base - height)
    pts = [(cx - half_w, base)]
    steps = 5
    for i in range(1, steps):
        t = i / steps
        x = cx - half_w + (peak[0] - (cx - half_w)) * t
        y = base - height * t + rng.uniform(-0.06, 0.06) * height * (1 - t)
        pts.append((x, y))
    pts.append(peak)
    for i in range(1, steps):
        t = i / steps
        x = peak[0] + (cx + half_w - peak[0]) * t
        y = base - height * (1 - t) + rng.uniform(-0.06, 0.06) * height * t
        pts.append((x, y))
    pts.append((cx + half_w, base))
    # Hřbet přehybu vede od vrcholu šikmo dolů – pravá plocha je ve stínu.
    ridge_end = (peak[0] + half_w * rng.uniform(0.05, 0.35), base)
    mid = (peak[0] + (ridge_end[0] - peak[0]) * 0.45 + rng.uniform(-0.05, 0.05) * half_w,
           peak[1] + height * 0.45)
    shade = [peak] + pts[steps + 1:] + [ridge_end, mid]
    return pts, shade, peak


def build_fiber(rng, out: Path):
    field = fiber_field(512, 512, rng)
    from paperlib import save_gray
    save_gray(field, out / "paper" / "paper_fiber.png")
    build_smooth_noise(rng, out)
    return field


def build_smooth_noise(rng, out: Path):
    """Hladký periodický šum (4 kanály) pro trhané hrany a vlnění vrstev v shaderu."""
    from PIL import Image
    from paperlib import periodic_noise
    chans = []
    for power in (3.2, 2.6, 2.2, 3.6):
        n = periodic_noise(256, 256, power, rng)
        n = (n - n.min()) / (n.max() - n.min())
        chans.append(n)
    arr = (np.dstack(chans) * 255 + 0.5).astype(np.uint8)
    (out / "paper").mkdir(parents=True, exist_ok=True)
    Image.fromarray(arr, "RGBA").save(out / "paper" / "noise_smooth.png", optimize=True)


def layer_sky(fiber, rng, out: Path):
    c = Canvas(TILE, 560, wrap_x=True, fiber=fiber)
    # Slunce: dvě vrstvy papíru s trhaným okrajem.
    sun = tear(ellipse(1960, 150, 78, 78, 90), 2.2, rng, step=3)
    c.shape(sun, P.SUN, fiber=0.08, shadow=(4, 5, 4, 0.12), rim=(2, P.SUN_LIGHT, 0.6))
    c.shape(tear(ellipse(1950, 140, 52, 52, 70), 1.5, rng), P.SUN_LIGHT, fiber=0.06)
    # Mraky: kupovité laloky z kruhů, spodek zarovnaný, pod nimi stínová vrstva.
    for cx, cy, w, h in [(380, 300, 300, 105), (980, 200, 190, 66), (1480, 330, 230, 78),
                         (2180, 290, 280, 98), (2620, 170, 170, 60)]:
        lobes = []
        n = max(4, int(w / 70))
        for i in range(n):
            t = (i + 0.5) / n
            r = h * (0.32 + 0.55 * math.sin(math.pi * t) ** 1.3) * rng.uniform(0.85, 1.12)
            x = cx - w / 2 + w * t
            lobes.append((x, cy - r * 0.55, r))
        for i in range(n - 1):
            t = (i + 1.0) / n
            r = h * (0.45 + 0.5 * math.sin(math.pi * t)) * rng.uniform(0.8, 1.0)
            lobes.append((cx - w / 2 + w * t, cy - r * 0.95, r * 0.8))
        base = [(cx - w / 2 - h * 0.2, cy), (cx + w / 2 + h * 0.2, cy),
                (cx + w / 2 + h * 0.1, cy - h * 0.25), (cx - w / 2 - h * 0.1, cy - h * 0.25)]
        for layer, (dx, dy, col) in enumerate([(16, 12, P.CLOUD_SHADE), (0, 0, P.CLOUD)]):
            polys = [tear(transform(ellipse(x, y, r, r, 40), dx, dy), 1.4, rng, step=4)
                     for x, y, r in lobes]
            polys.append(transform(base, dx, dy))
            # Spodní hrana mraku je rovná: nic pod základnou.
            polys = [[(px, min(py, cy + dy)) for px, py in poly] for poly in polys]
            c.shape(polys, col, fiber=0.05, shadow=(8, 10, 7, 0.10) if layer == 0 else None)
        c.crease((cx - w * 0.3, cy - h * 0.18), (cx + w * 0.25, cy - h * 0.15), 3, P.CLOUD_SHADE, 0.35)
    # Skládaní papíroví ptáčci (dvě křídla s přehybem).
    for bx, by, size, flip in [(1250, 120, 26, 1), (1330, 165, 20, -1), (610, 230, 18, 1)]:
        wing_l = [(bx, by), (bx - size * flip, by - size * 0.7), (bx - size * 0.35 * flip, by + size * 0.15)]
        wing_r = [(bx, by), (bx + size * 0.9 * flip, by - size * 0.45), (bx + size * 0.3 * flip, by + size * 0.2)]
        body = [(bx - size * 0.5 * flip, by + size * 0.1), (bx + size * 0.7 * flip, by - size * 0.05),
                (bx + size * 0.2 * flip, by + size * 0.3)]
        c.shape(body, P.LEAF_RUST, fiber=0.05, shadow=(3, 4, 3, 0.12))
        c.shape(wing_l, P.LEAF_RUST_LIGHT, fiber=0.05)
        c.shape(wing_r, mix(P.LEAF_RUST, "#000000", 0.12), fiber=0.05)
    c.save(out / "layers" / "sky_decor.png")


def layer_mountains(fiber, rng, out: Path):
    h = 640
    c = Canvas(TILE, h, wrap_x=True, fiber=fiber)
    base = h - 40
    # Vzdálená řada (bledší), pak bližší řada hor.
    for row, (count, hmin, hmax, wmin, wmax, lit, shade, snow_t, shadow_op) in enumerate([
        (9, 300, 470, 260, 420, P.MTN_FAR_LIT, P.MTN_FAR_SHADE, 0.8, 0.07),
        (8, 220, 400, 240, 380, P.MTN_LIT, P.MTN_SHADE, 0.55, 0.12),
        (10, 120, 220, 180, 300, mix(P.MTN_SHADE, P.HILL_BLUE, 0.4), mix(P.MTN_SHADE, P.HILL_BLUE_SHADE, 0.7),
         0.0, 0.14),
    ]):
        xs = np.sort(rng.uniform(0, TILE, count))
        for x in xs:
            height = rng.uniform(hmin, hmax)
            half = rng.uniform(wmin, wmax)
            pts, sh, peak = mountain(x, base + row * 30, height, half, rng, rng.uniform(-0.25, 0.25))
            pts = tear(pts, 2.0, rng, step=4)
            c.shape(pts, lit, fiber=0.07, shadow=(5, 6, 5, shadow_op))
            c.shape(tear(sh, 1.6, rng, step=4), shade, fiber=0.07)
            left_base = (pts[0][0] + half * rng.uniform(0.25, 0.6), base + row * 30)
            facet = [peak, left_base, (peak[0] - half * rng.uniform(0.15, 0.35), peak[1] + height * 0.55)]
            c.shape(facet, mix(lit, shade, 0.35), fiber=0.07)
            if height > 300 - row * 60:
                # Sněhová čepice s pilovitým spodním okrajem.
                cap_h = height * rng.uniform(0.18, 0.26)
                cap = [peak]
                n = 7
                left_x = peak[0] - cap_h * (half / height) * 1.05
                right_x = peak[0] + cap_h * (half / height) * 1.05
                cap.append((right_x, peak[1] + cap_h))
                for i in range(1, n):
                    t = i / n
                    x2 = right_x + (left_x - right_x) * t
                    y2 = peak[1] + cap_h * (0.62 if i % 2 else 1.0) + rng.uniform(-6, 6)
                    cap.append((x2, y2))
                cap.append((left_x, peak[1] + cap_h))
                c.shape(tear(cap, 1.2, rng, step=3), mix(P.SNOW, lit, 1 - snow_t), fiber=0.05)
                ridge = [peak, (peak[0] + cap_h * 0.3, peak[1] + cap_h * 0.95),
                         (right_x, peak[1] + cap_h)]
                c.shape(ridge + [(peak[0] + 2, peak[1] + 4)], mix(P.SNOW_SHADE, shade, 0.3), fiber=0.05)
    # Mlžný pás u úpatí sjednotí přechod ke střední vrstvě.
    haze = [(0, base - 70), (TILE, base - 70), (TILE, h), (0, h)]
    c.shape(haze, P.MTN_FAR_SHADE, fiber=0.04, gradient=(P.HILL_BLUE, base - 70, h))
    c.save(out / "layers" / "mountains.png")


def house(c, x, base, w, hgt, rng, church=False):
    roof_h = hgt * 0.65
    wall = [(x, base), (x, base - hgt), (x + w, base - hgt), (x + w, base)]
    c.shape(wall, P.WALL, fiber=0.06, shadow=(3, 3, 2, 0.15))
    c.shape([(x + w * 0.62, base), (x + w * 0.62, base - hgt), (x + w, base - hgt), (x + w, base)],
            P.WALL_SHADE, fiber=0.06)
    roof = [(x - w * 0.08, base - hgt + 2), (x + w * 0.5, base - hgt - roof_h), (x + w * 1.08, base - hgt + 2)]
    c.shape(roof, P.ROOF, fiber=0.07, shadow=(2, 3, 2, 0.15))
    c.shape([(x + w * 0.5, base - hgt - roof_h), (x + w * 1.08, base - hgt + 2), (x + w * 0.62, base - hgt + 2)],
            P.ROOF_SHADE, fiber=0.07)
    for i in range(int(w // 22)):
        wx = x + 8 + i * 22
        if wx + 8 < x + w - 4:
            c.shape([(wx, base - hgt * 0.62), (wx + 7, base - hgt * 0.62), (wx + 7, base - hgt * 0.4),
                     (wx, base - hgt * 0.4)], P.WINDOW, fiber=0.02)
    if church:
        tw = w * 0.42
        tx = x + w * 0.29
        th = hgt * 2.6
        c.shape([(tx, base - hgt), (tx, base - th), (tx + tw, base - th), (tx + tw, base - hgt)],
                P.WALL, fiber=0.06, shadow=(3, 3, 2, 0.15))
        c.shape([(tx + tw * 0.6, base - hgt), (tx + tw * 0.6, base - th), (tx + tw, base - th),
                 (tx + tw, base - hgt)], P.WALL_SHADE, fiber=0.06)
        spire = [(tx - 3, base - th), (tx + tw / 2, base - th - hgt * 1.4), (tx + tw + 3, base - th)]
        c.shape(spire, P.ROOF_SHADE, fiber=0.06)
        c.shape([(tx + tw / 2, base - th - hgt * 1.4), (tx + tw + 3, base - th), (tx + tw * 0.55, base - th)],
                mix(P.ROOF_SHADE, "#000000", 0.15), fiber=0.06)
        c.crease((tx + tw / 2, base - th - hgt * 1.4), (tx + tw / 2, base - th - hgt * 1.4 - 16), 2.0, P.INK, 0.8)
        c.crease((tx + tw / 2 - 6, base - th - hgt * 1.4 - 10), (tx + tw / 2 + 6, base - th - hgt * 1.4 - 10),
                 2.0, P.INK, 0.8)
        c.shape(ellipse(tx + tw / 2, base - th + hgt * 0.45, 5, 7, 16), P.WINDOW, fiber=0.0)


def viaduct(c, x0, x1, deck_y, ground_y, rng):
    spans = 5
    width = (x1 - x0) / spans
    pier = width * 0.2
    spring = deck_y + (ground_y - deck_y) * 0.42
    for i in range(spans):
        a = x0 + i * width
        b = a + width
        poly = [(a, deck_y), (b, deck_y), (b, spring)]
        rx = (width - pier) / 2
        cx = (a + b) / 2
        for k in range(19):
            ang = math.pi * k / 18
            poly.append((cx + math.cos(ang) * rx, spring - math.sin(ang) * rx * 0.9 + rx * 0.1))
        poly.append((a, spring))
        c.shape(poly, P.STONE, fiber=0.06, shadow=(3, 4, 3, 0.12))
    for i in range(spans + 1):
        px = x0 + i * width
        c.shape([(px - pier / 2, spring - 4), (px + pier / 2, spring - 4), (px + pier / 2 + 6, ground_y),
                 (px - pier / 2 - 6, ground_y)], P.STONE, fiber=0.06, shadow=(3, 4, 3, 0.12))
        c.shape([(px + pier * 0.1, spring - 4), (px + pier / 2, spring - 4), (px + pier / 2 + 6, ground_y),
                 (px + pier * 0.1, ground_y)], P.STONE_SHADE, fiber=0.06)
    c.shape([(x0 - 8, deck_y - 10), (x1 + 8, deck_y - 10), (x1 + 8, deck_y + 8), (x0 - 8, deck_y + 8)],
            P.STONE, fiber=0.06, shadow=(2, 3, 2, 0.15))


def layer_mid(fiber, rng, out: Path):
    h = 720
    c = Canvas(TILE, h, wrap_x=True, fiber=fiber)
    # Zadní modrošedé kopce s mlžnými jedlemi.
    for k in range(3):
        y_base = 330 + k * 70
        pts = [(-40, h)]
        for i in range(0, 61):
            x = -40 + i * (TILE + 80) / 60
            y = y_base - 60 * math.sin(i * 0.37 + k * 1.7) - 40 * math.sin(i * 0.11 + k)
            pts.append((x, y))
        pts.append((TILE + 40, h))
        col = [P.HILL_BLUE, P.HILL_SAGE_SHADE, P.HILL_SAGE][k]
        c.shape(tear(pts, 2.5, rng, step=6, closed=True), col, fiber=0.06, shadow=(4, 6, 6, 0.10))
        if k == 0:
            for x in np.sort(rng.uniform(0, TILE, 70)):
                yb = y_base - 60 * math.sin((x + 40) / ((TILE + 80) / 60) * 0.37) + 30
                hh = rng.uniform(50, 95)
                full, sh, tr = pine(x, yb, hh, hh * 0.42, 4, rng)
                c.shape(full, P.PINE_MIST, fiber=0.06)
                c.shape(sh, P.PINE_MIST_SHADE, fiber=0.06)
    # Vesnice s kostelem na kopci.
    vx, vy = 820, 410
    for dx, w, hh, church in [(-140, 70, 52, False), (-60, 64, 58, False), (20, 72, 60, True),
                              (110, 80, 50, False), (210, 62, 46, False), (290, 70, 44, False)]:
        house(c, vx + dx, vy + (abs(dx) * 0.08), w, hh, rng, church)
    # Viadukt a skalní stěna s vodopádem.
    viaduct(c, 1780, 2290, 360, 560, rng)
    cliff = [(2300, 470), (2340, 440), (2420, 430), (2520, 438), (2600, 452), (2640, 480), (2650, 720),
             (2290, 720)]
    c.shape(tear(cliff, 3, rng, step=5), P.ROCK, fiber=0.08, shadow=(5, 6, 5, 0.12))
    c.shape(tear([(2470, 434), (2520, 438), (2600, 452), (2640, 480), (2650, 720), (2480, 720)], 3, rng,
                 step=5), P.ROCK_SHADE, fiber=0.08)
    for i in range(7):
        x = 2405 + i * 11
        c.shape([(x, 436), (x + 10, 436), (x + 12 + rng.uniform(-2, 2), 640), (x - 2, 640)],
                mix(P.WATER_LIGHT, P.FOAM, (i % 2) * 0.6), fiber=0.04)
    c.shape(tear(ellipse(2445, 640, 70, 18, 40), 2, rng), P.FOAM, fiber=0.03)
    # Střední les: řady jedlí po svazích.
    for row, (count, hmin, hmax, ybase, col, shade) in enumerate([
        (90, 70, 120, 520, P.PINE_MID, P.PINE_MID_SHADE),
        (70, 90, 150, 600, mix(P.PINE_MID, P.PINE_NEAR, 0.35), mix(P.PINE_MID_SHADE, P.PINE_NEAR_SHADE, 0.35)),
    ]):
        for x in np.sort(rng.uniform(0, TILE, count)):
            if row == 0 and (vx - 200 < x < vx + 380 or 2290 < x < 2660):
                continue
            yb = ybase + 25 * math.sin(x * 0.004 + row) + rng.uniform(-10, 10)
            hh = rng.uniform(hmin, hmax)
            full, sh, tr = pine(x, yb, hh, hh * 0.45, 5, rng)
            c.shape(full, col, fiber=0.06, shadow=(3, 4, 3, 0.12))
            c.shape(sh, shade, fiber=0.06)
    # Neprůhledný spodek: travnatý svah, který lze v Godotu prodloužit dolů.
    bottom = [(-20, 650)]
    for i in range(41):
        x = -20 + i * (TILE + 40) / 40
        bottom.append((x, 640 - 18 * math.sin(i * 0.9) + rng.uniform(-6, 6)))
    bottom += [(TILE + 20, h + 5), (-20, h + 5)]
    c.shape(bottom, P.HILL_BLUE_SHADE, fiber=0.05)
    c.save(out / "layers" / "midground.png")


def layer_near(fiber, rng, out: Path):
    h = 620
    c = Canvas(TILE, h, wrap_x=True, fiber=fiber)
    # Řeka se světlými odlesky v dolní části.
    c.shape([(-20, 430), (TILE + 20, 430), (TILE + 20, h + 5), (-20, h + 5)], P.WATER, fiber=0.05,
            gradient=(P.WATER_DEEP, 430, h))
    for _ in range(90):
        x = rng.uniform(0, TILE)
        y = rng.uniform(450, h - 10)
        w = rng.uniform(30, 120)
        c.shape(tear([(x, y), (x + w, y - 2), (x + w * 0.9, y + 3), (x + 4, y + 4)], 0.6, rng, step=4),
                P.WATER_LIGHT, fiber=0.02)
    # Břehy a tmavé jedle.
    for side_x in range(0, TILE, 700):
        bank = [(side_x - 60, 470), (side_x + 40, 410), (side_x + 220, 400), (side_x + 330, 440),
                (side_x + 300, 480), (side_x - 40, 490)]
        c.shape(tear(bank, 3, rng, step=5), P.HILL_GREEN, fiber=0.07, shadow=(4, 6, 5, 0.18))
    for row, (count, hmin, hmax, ybase, col, shade) in enumerate([
        (36, 160, 260, 440, P.PINE_NEAR, P.PINE_NEAR_SHADE),
        (22, 220, 340, 470, P.PINE_DEEP, P.PINE_DEEP_SHADE),
    ]):
        xs = np.sort(rng.uniform(0, TILE, count))
        for x in xs:
            if 1050 < x < 1700 and row == 1:
                continue  # průhled na řeku
            yb = ybase + rng.uniform(-12, 12)
            hh = rng.uniform(hmin, hmax)
            full, sh, tr = pine(x, yb, hh, hh * 0.46, 6, rng)
            c.shape(tr, P.TRUNK, fiber=0.05)
            c.shape(tear(full, 1.4, rng, step=4), col, fiber=0.07, shadow=(5, 7, 5, 0.2))
            c.shape(sh, shade, fiber=0.07)
    c.save(out / "layers" / "near.png")


def leaf(cx, cy, length, width, angle, bend=0.15):
    """Špičatý list: obrys a stínovaná půlka podél středního žebra."""
    pts_l, pts_r = [], []
    n = 14
    for i in range(n + 1):
        t = i / n
        x = length * t
        y_off = math.sin(math.pi * t) ** 0.8 * width / 2
        curve = bend * length * (t * t - t) * 0.5
        pts_l.append((x, -y_off + curve))
        pts_r.append((x, y_off + curve))
    outline = pts_l + list(reversed(pts_r[1:-1]))
    half = pts_l
    rib = [(length * t, bend * length * (t * t - t) * 0.5) for t in (0, 1)]
    def place(p):
        return transform(p, cx, cy, 1, 1, angle, 0, 0)
    return place(outline), place(half + [(length, 0)]), place(rib)


def fg_clump(name, fiber, rng, out: Path, w, h, leaves, flowers=0):
    c = Canvas(w, h, fiber=fiber)
    base_x, base_y = w / 2, h - 4
    for i, (col, light) in enumerate(leaves):
        ang = -math.pi / 2 + rng.uniform(-1.15, 1.15)
        length = rng.uniform(0.45, 0.9) * h
        width = length * rng.uniform(0.28, 0.42)
        outline, half, rib = leaf(base_x + rng.uniform(-w * 0.18, w * 0.18), base_y, length, width, ang,
                                  rng.uniform(-0.35, 0.35))
        c.shape(outline, light, fiber=0.08, shadow=(8, 10, 8, 0.28))
        c.shape(half, col, fiber=0.08)
        c.crease(rib[0], rib[1], 3.0, mix(light, "#ffffff", 0.25), 0.55)
        # Postranní žilky naznačí přehyby.
        for t in (0.3, 0.5, 0.7):
            px = rib[0][0] + (rib[1][0] - rib[0][0]) * t
            py = rib[0][1] + (rib[1][1] - rib[0][1]) * t
            vx = math.cos(ang + 0.7) * width * 0.35
            vy = math.sin(ang + 0.7) * width * 0.35
            c.crease((px, py), (px + vx, py + vy), 2.0, mix(light, "#000000", 0.2), 0.35)
    for _ in range(flowers):
        fx = base_x + rng.uniform(-w * 0.25, w * 0.25)
        fy = rng.uniform(h * 0.25, h * 0.55)
        c.crease((fx, fy), (base_x + rng.uniform(-20, 20), base_y), 5, P.LEAF_SAGE, 1.0)
        r = rng.uniform(34, 48)
        for k in range(5):
            a = k * math.tau / 5 + rng.uniform(-0.1, 0.1)
            petal = leaf(fx, fy, r, r * 0.62, a, 0.0)
            c.shape(petal[0], P.FLOWER, fiber=0.05, shadow=(3, 4, 3, 0.2))
            c.shape(petal[1], P.FLOWER_SHADE, fiber=0.05)
        c.shape(ellipse(fx, fy, r * 0.22, r * 0.22, 20), P.CAP, fiber=0.05)
    c.save(out / "layers" / f"{name}.png")


def build(out: Path, seed: int = 2026):
    rng = np.random.default_rng(seed)
    fiber = build_fiber(rng, out)
    layer_sky(fiber, np.random.default_rng(seed + 1), out)
    layer_mountains(fiber, np.random.default_rng(seed + 2), out)
    layer_mid(fiber, np.random.default_rng(seed + 3), out)
    layer_near(fiber, np.random.default_rng(seed + 4), out)
    fg_clump("fg_leaves_teal", fiber, np.random.default_rng(seed + 5), out, 620, 640,
             [(P.LEAF_TEAL, P.LEAF_TEAL_LIGHT)] * 7 + [(P.LEAF_SAGE, P.LEAF_SAGE_LIGHT)] * 2)
    fg_clump("fg_leaves_rust", fiber, np.random.default_rng(seed + 6), out, 560, 600,
             [(P.LEAF_RUST, P.LEAF_RUST_LIGHT)] * 4 + [(P.LEAF_TEAL, P.LEAF_TEAL_LIGHT)] * 3, flowers=1)
    fg_clump("fg_fern_sage", fiber, np.random.default_rng(seed + 7), out, 520, 520,
             [(P.LEAF_SAGE, P.LEAF_SAGE_LIGHT)] * 8)


if __name__ == "__main__":
    build(Path(__file__).resolve().parents[1])
