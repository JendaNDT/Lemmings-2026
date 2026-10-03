"""Papírová líheň (chatka na kůlech) a východ (domek se světlem a vlajkou).

Měřítko: PROP_SCALE pixelů textury na jeden logický pixel simulace. Kotevní
body (místo líhně / východu) jsou zapsané v props.json, Godot podle nich
objekt umístí přesně na bod z levelu.
"""

from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np

import palette as P
from paperlib import Canvas, ellipse, mix, tear

PROP_SCALE = 24


def planks(c, x0, y0, x1, y1, rng, vertical=True, base=P.WOOD, dark=P.WOOD_DARK, step=30):
    """Prkna z kraftového papíru s mezerami a jemným odstínem každého prkna."""
    if vertical:
        x = x0
        while x < x1 - 2:
            w = min(step * rng.uniform(0.8, 1.2), x1 - x)
            col = mix(base, dark, rng.uniform(0.0, 0.3))
            c.shape(tear([(x + 1, y0), (x + w - 1, y0), (x + w - 1, y1), (x + 1, y1)], 0.8, rng, step=6),
                    col, fiber=0.10, shadow=(3, 3, 2, 0.3), bevel=(2.5, 0.22, 0.2))
            c.crease((x + w * 0.5, y0 + 6), (x + w * 0.5 + rng.uniform(-3, 3), y1 - 6), 1.2, dark, 0.25)
            x += w
    else:
        y = y0
        while y < y1 - 2:
            hgt = min(step * rng.uniform(0.8, 1.2), y1 - y)
            col = mix(base, dark, rng.uniform(0.0, 0.3))
            c.shape(tear([(x0, y + 1), (x1, y + 1), (x1, y + hgt - 1), (x0, y + hgt - 1)], 0.8, rng, step=6),
                    col, fiber=0.10, shadow=(2, 2, 1.5, 0.25))
            y += hgt


def leaf_emblem(c, cx, cy, size, color):
    """Znak lístku na praporu: střední stonek a tři páry lístků."""
    c.crease((cx, cy + size * 0.55), (cx, cy - size * 0.5), size * 0.07, color, 1.0)
    for i, (dy, s) in enumerate([(-0.45, 0.35), (-0.1, 0.42), (0.25, 0.4)]):
        for side in (-1, 1):
            if i == 0 and side == 1:
                continue
            ang = -math.pi / 2 + side * 0.9
            lx = cx + side * size * 0.02
            ly = cy + dy * size
            pts = []
            for k in range(12):
                t = k / 11
                r = math.sin(math.pi * t) * s * size * 0.22
                px = lx + math.cos(ang) * s * size * t - math.sin(ang) * r
                py = ly + math.sin(ang) * s * size * t + math.cos(ang) * r
                pts.append((px, py))
            for k in range(11, -1, -1):
                t = k / 11
                r = -math.sin(math.pi * t) * s * size * 0.22
                px = lx + math.cos(ang) * s * size * t - math.sin(ang) * r
                py = ly + math.sin(ang) * s * size * t + math.cos(ang) * r
                pts.append((px, py))
            c.shape(pts, color, fiber=0.0)
    top = [(cx, cy - size * 0.75), (cx + size * 0.12, cy - size * 0.45), (cx, cy - size * 0.38),
           (cx - size * 0.12, cy - size * 0.45)]
    c.shape(top, color, fiber=0.0)


def banner(c, x, y, w, h, rng):
    pts = [(x, y), (x + w, y), (x + w, y + h), (x + w / 2, y + h - w * 0.35), (x, y + h)]
    c.shape(tear(pts, 0.8, rng, step=5), P.BANNER, fiber=0.06, shadow=(4, 5, 3, 0.3))
    c.shape([(x + w * 0.55, y), (x + w, y), (x + w, y + h), (x + w / 2, y + h - w * 0.35)],
            mix(P.BANNER, P.IVORY_SHADE, 0.6), fiber=0.06)
    leaf_emblem(c, x + w / 2, y + h * 0.42, w * 0.62, P.ROOF_TEAL_DARK)


def hatch(fiber, rng, out: Path) -> dict:
    s = PROP_SCALE
    w, h = 44 * s, 40 * s
    c = Canvas(w, h, fiber=fiber)
    # Kotva = bod líhně: střed padacích dvířek v podlaze.
    ax, ay = 20 * s, 36 * s
    body_l, body_r = ax - 13 * s, ax + 13 * s
    body_t = ay - 17 * s
    # Zadní stěna a tmavý vnitřek otevřené chatky.
    planks(c, body_l, body_t, body_r, ay, rng, True)
    inner = [(ax - 8 * s, body_t + 3.2 * s), (ax + 9 * s, body_t + 3.2 * s), (ax + 9 * s, ay - 0.6 * s),
             (ax - 8 * s, ay - 0.6 * s)]
    c.shape(tear(inner, 1.0, rng, step=6), "#231a16", fiber=0.08, shadow=(-4, -5, 4, 0.35))
    c.shape([(ax - 8 * s, ay - 2.8 * s), (ax + 9 * s, ay - 2.8 * s), (ax + 9 * s, ay - 0.6 * s),
             (ax - 8 * s, ay - 0.6 * s)], "#3a2b22", fiber=0.06)
    # Rám dveří a okénko na boční stěně.
    for xs in (ax - 9 * s, ax + 8 * s):
        c.shape([(xs, body_t + 2.4 * s), (xs + 1.2 * s, body_t + 2.4 * s), (xs + 1.2 * s, ay),
                 (xs, ay)], P.WOOD_LIGHT, fiber=0.08, shadow=(3, 3, 2, 0.3))
    c.shape([(ax - 9.4 * s, body_t + 1.8 * s), (ax + 9.6 * s, body_t + 1.8 * s),
             (ax + 9.6 * s, body_t + 3.2 * s), (ax - 9.4 * s, body_t + 3.2 * s)], P.WOOD_LIGHT,
            fiber=0.08, shadow=(3, 3, 2, 0.3))
    c.shape([(body_l + 1.2 * s, body_t + 5 * s), (body_l + 3.6 * s, body_t + 5 * s),
             (body_l + 3.6 * s, body_t + 8 * s), (body_l + 1.2 * s, body_t + 8 * s)], "#2c211b", fiber=0.04)
    c.crease((body_l + 2.4 * s, body_t + 5 * s), (body_l + 2.4 * s, body_t + 8 * s), 3, P.WOOD_LIGHT, 1)
    c.crease((body_l + 1.2 * s, body_t + 6.5 * s), (body_l + 3.6 * s, body_t + 6.5 * s), 3, P.WOOD_LIGHT, 1)
    # Podlaha s otvorem pro padací dvířka (dvířka kreslí Godot samostatně).
    for x0, x1 in [(body_l - 2 * s, ax - 5.5 * s), (ax + 5.5 * s, body_r + 2 * s)]:
        c.shape(tear([(x0, ay), (x1, ay), (x1, ay + 1.4 * s), (x0, ay + 1.4 * s)], 0.6, rng, step=6),
                P.WOOD_LIGHT, fiber=0.08, shadow=(3, 5, 3, 0.35))
        c.shape([(x0, ay + 0.8 * s), (x1, ay + 0.8 * s), (x1, ay + 1.4 * s), (x0, ay + 1.4 * s)],
                P.WOOD_DARK, fiber=0.08)
    # Skládaná tyrkysová střecha: dvě plochy a přehyb na hřebeni.
    ridge = (ax + 1 * s, body_t - 10 * s)
    roof = [(body_l - 4 * s, body_t + 1.2 * s), ridge, (body_r + 5 * s, body_t + 1.2 * s),
            (body_r + 5 * s, body_t + 2.4 * s), (body_l - 4 * s, body_t + 2.4 * s)]
    roof_poly = tear(roof, 1.0, rng, step=6)
    c.shape(roof_poly, P.ROOF_TEAL, fiber=0.09, shadow=(7, 10, 6, 0.4))
    c.shape([ridge, (body_r + 5 * s, body_t + 1.2 * s), (body_r + 5 * s, body_t + 2.4 * s),
             (ax + 3 * s, body_t + 2.4 * s)], P.ROOF_TEAL_DARK, fiber=0.09)
    c.shape([(body_l - 4 * s, body_t + 1.2 * s), ridge, (ax - 2 * s, body_t + 2.4 * s),
             (body_l - 4 * s, body_t + 2.4 * s)], P.ROOF_TEAL_LIGHT, fiber=0.09)
    for k in range(1, 5):
        t = k / 5
        c.crease((ridge[0] - (ridge[0] - body_l + 4 * s) * t, ridge[1] + (body_t + 1.2 * s - ridge[1]) * t),
                 (ridge[0] - (ridge[0] - body_l + 4 * s) * t + 3 * s, body_t + 2.2 * s), 2.0,
                 P.ROOF_TEAL_DARK, 0.35)
    c.core(roof_poly, 4.0, 0.5)
    banner(c, body_r + 1.5 * s, body_t + 3 * s, 6 * s, 9 * s, rng)
    path = out / "props" / "hatch.png"
    c.save(path)
    # Kůl a příčka žebříku jsou opakovatelné dlaždice.
    post = Canvas(int(2.2 * s), 4 * s, fiber=fiber)
    post.fill_rect(P.WOOD, 0, 0, int(2.2 * s), 4 * s, fiber=0.12)
    post.fill_rect(P.WOOD_DARK, int(1.4 * s), 0, int(2.2 * s), 4 * s, fiber=0.12)
    post.save(out / "props" / "hatch_post.png")
    rung = Canvas(6 * s, 3 * s, fiber=fiber)
    for x0 in (0, int(5 * s)):
        rung.fill_rect(P.WOOD, x0, 0, x0 + s, 3 * s, fiber=0.12)
    rung.shape([(s * 0.8, s * 1.1), (5.2 * s, s * 1.1), (5.2 * s, s * 1.9), (s * 0.8, s * 1.9)], P.WOOD_LIGHT,
               fiber=0.1, shadow=(2, 3, 2, 0.35))
    rung.save(out / "props" / "hatch_ladder.png")
    door = Canvas(int(6 * s), int(1.4 * s), fiber=fiber)
    door.fill_rect(P.WOOD_DARK, 0, 0, int(6 * s), int(1.4 * s), fiber=0.12)
    door.crease((s * 0.3, s * 0.5), (5.7 * s, s * 0.5), 2, P.WOOD_LIGHT, 0.5)
    door.save(out / "props" / "hatch_door.png")
    return {"texture": "props/hatch.png", "anchor": [ax / s, ay / s], "scale": s,
            "door": {"texture": "props/hatch_door.png", "left": [-5.5, 0.0], "right": [5.5, 0.0]},
            "posts": [[-11.5, 1.4], [10.0, 1.4]], "ladder_x": -16.5}


def exit_house(fiber, rng, out: Path) -> dict:
    s = PROP_SCALE
    w, h = 40 * s, 44 * s
    c = Canvas(w, h, fiber=fiber)
    ax, ay = 18 * s, 40 * s  # střed prahu dveří
    left, right = ax - 11 * s, ax + 12 * s
    top = ay - 17 * s
    # Stěny z ivorové lepenky, pravá strana ve stínu (přehyb na rohu).
    c.shape(tear([(left, ay), (left, top), (right, top), (right, ay)], 0.8, rng, step=6),
            P.IVORY, fiber=0.08, shadow=(8, 10, 7, 0.36), bevel=(3.0, 0.2, 0.16))
    c.shape([(ax + 7.5 * s, top), (right, top), (right, ay), (ax + 7.5 * s, ay)], P.IVORY_SHADE, fiber=0.08)
    for k in range(3):
        y = top + (k + 1) * 4.2 * s
        c.crease((left + 0.5 * s, y), (ax + 7.3 * s, y + rng.uniform(-4, 4)), 1.5, P.IVORY_SHADE, 0.4)
    # Štít pod střechou.
    gable = [(left, top + 0.5), (ax + 0.5 * s, top - 7.5 * s), (right, top + 0.5)]
    c.shape(gable, mix(P.IVORY, P.IVORY_SHADE, 0.2), fiber=0.08)
    # Zlatě zářící dveře; vnitřek je hlubší okr.
    door = [(ax - 4.5 * s, ay), (ax - 4.5 * s, ay - 12.5 * s), (ax + 4.5 * s, ay - 12.5 * s), (ax + 4.5 * s, ay)]
    c.shape(door, P.DOOR_DEEP, fiber=0.06, shadow=(-3, -4, 3, 0.25))
    c.shape([(ax - 3.4 * s, ay), (ax - 3.4 * s, ay - 11.2 * s), (ax + 4.5 * s, ay - 11.2 * s), (ax + 4.5 * s, ay)],
            P.DOOR_GLOW, fiber=0.05)
    c.shape([(ax - 4.5 * s, ay), (ax + 5.5 * s, ay), (ax + 6.5 * s, ay + 1.2 * s), (ax - 5.5 * s, ay + 1.2 * s)],
            mix(P.DOOR_GLOW, P.IVORY, 0.5), fiber=0.05)
    # Střecha: dvě složené plochy přesahující stěny.
    ridge = (ax + 0.5 * s, top - 9 * s)
    roof_l = [(left - 3 * s, top + 1.5 * s), ridge, (ax + 0.5 * s, top - 6.6 * s), (left - 1.2 * s, top + 2.6 * s)]
    roof_r = [ridge, (right + 3.5 * s, top + 1.5 * s), (right + 2 * s, top + 2.8 * s), (ax + 0.5 * s, top - 6.6 * s)]
    roof_l = tear(roof_l, 0.8, rng, step=6)
    roof_r = tear(roof_r, 0.8, rng, step=6)
    c.shape(roof_l, P.ROOF_TEAL_LIGHT, fiber=0.08, shadow=(6, 9, 6, 0.36))
    c.shape(roof_r, P.ROOF_TEAL, fiber=0.08, shadow=(6, 9, 6, 0.36))
    c.core([roof_l, roof_r], 4.0, 0.5)
    c.crease(ridge, (ax + 0.5 * s, top - 6.6 * s), 2.0, P.ROOF_TEAL_DARK, 0.6)
    # Stožár vlajky (vlajku samotnou kreslí Godot – vlaje podle herního času).
    pole_x = right - 2 * s
    c.shape([(pole_x, top - 2 * s), (pole_x + 0.8 * s, top - 2 * s), (pole_x + 0.8 * s, top - 20 * s),
             (pole_x, top - 20 * s)], P.WOOD, fiber=0.08, shadow=(3, 4, 2, 0.3))
    c.shape(ellipse(pole_x + 0.4 * s, top - 20.4 * s, 0.8 * s, 0.8 * s, 20), P.CAP, fiber=0.05)
    c.save(out / "props" / "exit.png")
    flag = Canvas(int(9 * s), int(6.5 * s), fiber=fiber)
    pts = [(0, 0), (9 * s, 0.3 * s), (7 * s, 3 * s), (9 * s, 6.2 * s), (0, 6.2 * s)]
    flag.shape(tear(pts, 0.6, rng, step=5), P.BANNER, fiber=0.06)
    flag.shape([(0, 3.1 * s), (8 * s, 3.1 * s), (9 * s, 6.2 * s), (0, 6.2 * s)],
               mix(P.BANNER, P.IVORY_SHADE, 0.5), fiber=0.06)
    leaf_emblem(flag, 3.6 * s, 3.1 * s, 4.4 * s, P.ROOF_TEAL_DARK)
    flag.save(out / "props" / "exit_flag.png")
    return {"texture": "props/exit.png", "anchor": [ax / s, ay / s], "scale": s,
            "flag": {"texture": "props/exit_flag.png", "pole_top": [(pole_x - ax) / s + 0.8, (top - 19.6 * s - ay) / s]},
            "door_center": [0.5, -6.0]}


def plants(fiber, rng, out: Path) -> list:
    """Drobné rostlinky na povrch plošin: kotva je střed spodní hrany."""
    from build_backgrounds import leaf
    s = PROP_SCALE
    specs = [
        ("plant_tuft", 9, 7, [(P.GRASS_LIT, P.GRASS_TOP), (P.LEAF_SAGE, P.LEAF_SAGE_LIGHT)] * 3, False),
        ("plant_fern", 10, 9, [(P.LEAF_TEAL, P.LEAF_TEAL_LIGHT), (P.LEAF_SAGE, P.LEAF_SAGE_LIGHT)] * 3, False),
        ("plant_flower", 11, 9, [(P.LEAF_SAGE, P.LEAF_SAGE_LIGHT)] * 4, True),
    ]
    out_specs = []
    for name, w, h, leaves, flower in specs:
        c = Canvas(int(w * s), int(h * s), fiber=fiber)
        bx, by = w * s / 2, h * s - 2
        for col, light in leaves:
            ang = -math.pi / 2 + rng.uniform(-1.0, 1.0)
            length = rng.uniform(0.45, 0.85) * (h - 1) * s
            outline, half, rib = leaf(bx + rng.uniform(-0.12, 0.12) * w * s, by, length,
                                      length * rng.uniform(0.32, 0.45), ang, rng.uniform(-0.3, 0.3))
            c.shape(outline, light, fiber=0.08, shadow=(4, 6, 4, 0.34))
            c.shape(half, col, fiber=0.08)
            c.crease(rib[0], rib[1], 2.0, mix(light, "#ffffff", 0.25), 0.5)
            c.core(outline, 3.0, 0.5)
        if flower:
            fx, fy = bx + 0.5 * s, by - (h - 2.6) * s
            c.crease((fx, fy), (bx, by), 4, P.LEAF_SAGE, 1.0)
            for k in range(5):
                a = k * math.tau / 5
                petal = leaf(fx, fy, 1.4 * s, 0.9 * s, a, 0.0)
                c.shape(petal[0], P.FLOWER, fiber=0.05, shadow=(2, 3, 2, 0.25))
                c.shape(petal[1], P.FLOWER_SHADE, fiber=0.05)
            c.shape(ellipse(fx, fy, 0.35 * s, 0.35 * s, 16), P.CAP, fiber=0.05)
        c.save(out / "props" / f"{name}.png")
        out_specs.append({"texture": f"props/{name}.png", "anchor": [w / 2, h - 2 / s]})
    return out_specs


def flytrap(fiber, rng, out: Path) -> dict:
    """Past: papírová masožravá rostlina. Dva stejné laloky (levý je zrcadlený)
    se otáčejí kolem kloubu na stonku; Godot je otevírá a zavírá podle tiků."""
    from build_backgrounds import leaf
    s = PROP_SCALE
    mouth = "#c85a45"
    mouth_dark = "#a4442f"
    # Lalok: kloub vlevo dole, vnitřní hrana se zuby míří doleva (k druhému laloku).
    lw, lh = 8.5, 11.4
    px, py = 2.0, 10.8
    lobe = Canvas(int(lw * s), int(lh * s), fiber=fiber)
    n = 24
    inner = [((px + 0.4 * t) * s, (py - 9.9 * t) * s) for t in (i / n for i in range(n + 1))]
    outer = [((px + 0.4 * t + 5.0 * math.sin(math.pi * t) ** 0.75 * (1.0 - 0.2 * t)) * s, (py - 9.9 * t) * s)
             for t in (i / n for i in range(n, -1, -1))]
    body = tear(inner + outer, 0.7, rng, step=5)
    lobe.shape(body, P.LEAF_SAGE_LIGHT, fiber=0.08, shadow=(4, 6, 4, 0.32), bevel=(2.5, 0.2, 0.18))
    # Stinná půlka laloku a jeho žilky.
    half = [((px + 0.4 * t + 2.6 * math.sin(math.pi * t) ** 0.75) * s, (py - 9.9 * t) * s)
            for t in (i / n for i in range(n, -1, -1))]
    lobe.shape(tear(half[::-1] + outer[::-1][::-1], 0.5, rng, step=5), P.LEAF_SAGE, fiber=0.08)
    # Červená „tlama“ podél vnitřní hrany.
    band = inner + [((px + 0.4 * t + 1.7 * math.sin(math.pi * t) ** 0.6) * s, (py - 9.9 * t) * s)
                    for t in (i / n for i in range(n, -1, -1))]
    lobe.shape(tear(band, 0.4, rng, step=4), mouth, fiber=0.06)
    for k in range(5):
        t = 0.2 + k * 0.15
        a = ((px + 0.6 + 0.4 * t) * s, (py - 9.9 * t) * s)
        b = ((px + 0.4 * t + 3.8 * math.sin(math.pi * t) ** 0.75) * s, (py - 9.9 * t + 1.2) * s)
        lobe.crease(a, b, 1.6, mouth_dark if k % 2 else P.LEAF_SAGE, 0.35)
    # Zuby: krémové trojúhelníky přes vnitřní hranu.
    teeth = []
    for k in range(8):
        t = 0.2 + k * 0.1
        x, y = (px + 0.4 * t) * s, (py - 9.9 * t) * s
        teeth.append([(x + 0.2 * s, y - 0.35 * s), (x - 1.6 * s, y - 0.05 * s), (x + 0.2 * s, y + 0.35 * s)])
    for tooth in teeth:
        lobe.shape(tooth, P.FLOWER, fiber=0.05, shadow=(2, 3, 2, 0.25))
    lobe.core(body, 3.0, 0.5)
    lobe.save(out / "props" / "trap_lobe.png")
    # Stonek s listy přitisknutými k zemi; kotva je střed spodní hrany.
    bw, bh = 14.0, 6.0
    ax, ay = 7.0, 5.8
    base = Canvas(int(bw * s), int(bh * s), fiber=fiber)
    for ang, length in ((math.pi + 0.32, 6.2), (-0.32, 6.0), (math.pi + 0.9, 4.0), (-0.85, 4.2)):
        outline, half_leaf, rib = leaf(ax * s, (ay - 0.3) * s, length * s, length * 0.36 * s, ang, 0.2)
        base.shape(outline, P.LEAF_SAGE_LIGHT, fiber=0.08, shadow=(3, 4, 3, 0.3))
        base.shape(half_leaf, P.LEAF_SAGE, fiber=0.08)
        base.crease(rib[0], rib[1], 1.6, P.GRASS_TOP, 0.4)
        base.core(outline, 2.5, 0.45)
    stem = [((ax - 0.5) * s, ay * s), ((ax - 0.35) * s, (ay - 3.6) * s), ((ax + 0.35) * s, (ay - 3.6) * s),
            ((ax + 0.5) * s, ay * s)]
    base.shape(tear(stem, 0.4, rng, step=4), P.LEAF_SAGE, fiber=0.08, shadow=(3, 3, 2, 0.3))
    base.shape(ellipse(ax * s, (ay - 3.5) * s, 0.9 * s, 0.6 * s, 20), P.LEAF_SAGE_LIGHT, fiber=0.06)
    base.save(out / "props" / "trap_base.png")
    return {"base": "props/trap_base.png", "lobe": "props/trap_lobe.png", "scale": s,
            "anchor": [ax, ay], "hinge": [0.0, -3.4], "lobe_pivot": [px, py]}


def build(out: Path, seed: int = 2027):
    from paperlib import fiber_field
    fiber = fiber_field(512, 512, np.random.default_rng(seed))
    data = {"hatch": hatch(fiber, np.random.default_rng(seed + 1), out),
            "exit": exit_house(fiber, np.random.default_rng(seed + 2), out),
            "plants": plants(fiber, np.random.default_rng(seed + 3), out),
            "trap": flytrap(fiber, np.random.default_rng(seed + 4), out)}
    (out / "props" / "props.json").write_text(json.dumps(data, indent=2) + "\n")


if __name__ == "__main__":
    build(Path(__file__).resolve().parents[1])
