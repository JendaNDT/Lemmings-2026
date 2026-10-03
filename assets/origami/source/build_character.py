"""Origami postavička jako vystřihovánka z dílů + pózy všech stavů.

Výstupy:
- actor/worker_atlas.png  – díly s přehyby, vláknem a vlastním stínem,
- actor/worker_rig.json   – oblasti dílů, klouby, pořadí kreslení a animace,
- source/previews/*.png   – kontaktní archy pro vizuální kontrolu (nejsou ve hře).

Souřadnice: logické pixely simulace, postava kouká doprava (+x), y roste dolů,
počátek mezi chodidly. Úhly ve stupních jako v Godotu (kladně = po směru
hodinových ručiček na obrazovce). Ruka a noha v nulové póze míří dolů.
"""

from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np
from PIL import Image

import palette as P
from paperlib import Canvas, ellipse, fiber_field, mix, tear

A = 32  # pixelů atlasu na logický pixel
PAD = 10
SHADOW = (0.11 * A, 0.13 * A, 2.0, 0.34)


def part_canvas(polys_bbox, fiber):
    xs = [x for x, _ in polys_bbox]
    ys = [y for _, y in polys_bbox]
    x0, y0 = min(xs), min(ys)
    w = int(math.ceil((max(xs) - x0) * A)) + PAD * 2
    h = int(math.ceil((max(ys) - y0) * A)) + PAD * 2
    c = Canvas(w, h, fiber=fiber)

    def to_px(points):
        return [((x - x0) * A + PAD, (y - y0) * A + PAD) for x, y in points]
    pivot = ((0 - x0) * A + PAD, (0 - y0) * A + PAD)
    return c, to_px, pivot


def paper(c, to_px, pts, color, rng, *, shadow=True, rim=None, fiber=0.07, amp=0.5):
    poly = tear(to_px(pts), amp, rng, step=3, fine=0.2)
    return c.shape(poly, color, fiber=fiber, shadow=SHADOW if shadow else None, rim=rim)


def facet(c, to_px, pts, color, fiber=0.07):
    c.shape(to_px(pts), color, fiber=fiber)


def crease(c, to_px, a, b, color, alpha=0.55, width=1.6):
    pa, pb = to_px([a, b])
    c.crease(pa, pb, width, color, alpha)


EDGE = (1.2, "#2a1d16", 0.35)


def make_parts(fiber, rng):
    parts = {}

    # --- noha: kalhoty + bota (pivot v kyčli) --------------------------------
    leg_pts = [(-0.55, -0.15), (0.55, -0.15), (0.6, 1.25), (1.2, 1.55), (1.25, 2.1), (-0.6, 2.1), (-0.55, 1.2)]
    c, tp, pivot = part_canvas(leg_pts, fiber)
    paper(c, tp, [(-0.55, -0.15), (0.55, -0.15), (0.5, 1.35), (-0.5, 1.35)], P.TROUSER, rng, rim=EDGE)
    facet(c, tp, [(0.05, -0.15), (0.55, -0.15), (0.5, 1.35), (0.1, 1.35)], mix(P.TROUSER, "#000000", 0.18))
    paper(c, tp, [(-0.62, 1.2), (0.6, 1.2), (1.2, 1.55), (1.25, 2.1), (-0.62, 2.1)], P.BOOT, rng, rim=EDGE)
    facet(c, tp, [(-0.62, 1.2), (0.6, 1.2), (1.2, 1.55), (-0.2, 1.6)], P.BOOT_LIGHT)
    parts["leg"] = (c, pivot)

    # --- trup: kabátek (pivot v kyčli, nahoru k ramenům) ----------------------
    coat = [(-1.15, -2.75), (1.05, -2.75), (1.55, -0.3), (1.75, 0.55), (-1.65, 0.55), (-1.45, -0.3)]
    c, tp, pivot = part_canvas(coat + [(1.9, 0.7), (-1.8, -2.9)], fiber)
    paper(c, tp, coat, P.JACKET, rng, rim=EDGE)
    # Světlejší levá chlopeň a tmavší pravá plocha, rozdělené přehybem.
    facet(c, tp, [(-1.15, -2.75), (-0.1, -2.75), (0.15, 0.55), (-1.65, 0.55), (-1.45, -0.3)], P.JACKET_LIGHT)
    facet(c, tp, [(0.55, -2.75), (1.05, -2.75), (1.55, -0.3), (1.75, 0.55), (0.75, 0.55)], P.JACKET_DARK)
    crease(c, tp, (-0.1, -2.75), (0.15, 0.55), "#0d3437", 0.5)
    crease(c, tp, (0.55, -2.75), (0.75, 0.55), "#9fd1c9", 0.35)
    # Límec a okrová spona.
    facet(c, tp, [(-0.55, -2.8), (0.65, -2.8), (0.1, -1.95)], P.JACKET_DARK)
    paper(c, tp, [(-0.2, -2.25), (0.35, -2.25), (0.3, -1.85), (-0.15, -1.85)], P.CAP, rng, shadow=False)
    paper(c, tp, [(-1.55, -0.45), (1.6, -0.45), (1.62, -0.1), (-1.58, -0.1)], P.JACKET_DARK, rng, shadow=False,
          amp=0.2)
    parts["torso"] = (c, pivot)

    # --- paže: rukáv + dlaň (pivot v rameni, míří dolů) -----------------------
    arm = [(-0.5, -0.2), (0.5, -0.2), (0.44, 1.85), (-0.44, 1.85)]
    c, tp, pivot = part_canvas(arm + [(0.6, 2.75), (-0.6, 2.75)], fiber)
    paper(c, tp, arm, P.JACKET_LIGHT, rng, rim=EDGE)
    facet(c, tp, [(0.05, -0.2), (0.5, -0.2), (0.44, 1.85), (0.05, 1.85)], P.JACKET)
    paper(c, tp, [(-0.47, 1.72), (0.47, 1.72), (0.42, 2.0), (-0.42, 2.0)], P.JACKET_DARK, rng, shadow=False)
    paper(c, tp, ellipse(0.0, 2.3, 0.44, 0.4, 20), P.HAND, rng, rim=EDGE, amp=0.15)
    parts["arm"] = (c, pivot)

    # --- hlava: hranatý obličej + tyrkysová kapuce vzadu (pivot v krku) -------
    face = [(-1.0, 0.1), (1.15, 0.1), (1.45, -1.2), (1.25, -2.55), (-0.9, -2.6), (-1.2, -1.25)]
    hood = [(-1.45, -2.45), (0.1, -2.75), (-0.35, -0.9), (-0.7, 0.2), (-1.55, 0.05), (-1.65, -1.2)]
    c, tp, pivot = part_canvas(face + hood + [(1.6, 0.3)], fiber)
    paper(c, tp, hood, P.JACKET_DARK, rng, rim=EDGE)
    paper(c, tp, face, P.FACE, rng, rim=EDGE, amp=0.3)
    facet(c, tp, [(0.25, 0.1), (1.15, 0.1), (1.45, -1.2), (0.6, -0.55)], P.FACE_SHADE)
    crease(c, tp, (0.6, -0.55), (1.45, -1.2), "#c29a72", 0.5)
    crease(c, tp, (0.6, -0.55), (0.25, 0.1), "#c29a72", 0.35)
    for ex in (0.35, 1.0):
        c.shape(tp(ellipse(ex, -1.35, 0.2, 0.24, 20)), P.INK, fiber=0.0)
        c.shape(tp(ellipse(ex + 0.06, -1.43, 0.06, 0.06, 10)), "#fff7e8", fiber=0.0)
    c.shape(tp(ellipse(0.75, -0.62, 0.22, 0.12, 16)), mix(P.FACE, P.LEAF_RUST_LIGHT, 0.25), fiber=0.0)
    parts["head"] = (c, pivot)

    # --- čepice: okrový kužel se dvěma plochami (pivot ve středu spodní hrany) -
    cap = [(-2.95, 0.3), (0.2, -2.45), (3.1, 0.3), (2.9, 0.6), (-2.75, 0.6)]
    c, tp, pivot = part_canvas(cap, fiber)
    paper(c, tp, cap, P.CAP, rng, rim=EDGE, amp=0.35)
    facet(c, tp, [(-2.95, 0.3), (0.2, -2.45), (-0.55, 0.45), (-2.75, 0.6)], P.CAP_LIGHT)
    facet(c, tp, [(0.2, -2.45), (3.1, 0.3), (2.9, 0.6), (1.05, 0.5)], P.CAP_DARK)
    crease(c, tp, (0.2, -2.45), (-0.55, 0.45), "#fff0c8", 0.55, 1.8)
    crease(c, tp, (0.2, -2.45), (1.05, 0.5), "#a35f1c", 0.5, 1.8)
    crease(c, tp, (-2.85, 0.42), (3.0, 0.42), "#a35f1c", 0.35, 1.4)
    parts["cap"] = (c, pivot)

    # --- nástroje (pivot v úchopu dlaně, osa nástroje = +y paže) --------------
    pick_pts = [(-0.18, -0.4), (0.18, -0.4), (0.18, 3.2), (-0.18, 3.2)]
    head_pts = [(-1.9, 2.75), (-0.6, 2.95), (0.0, 2.8), (0.6, 2.95), (1.9, 2.75), (0.4, 3.45), (-0.4, 3.45)]
    c, tp, pivot = part_canvas(pick_pts + head_pts + [(2.0, 3.6), (-2.0, -0.5)], fiber)
    paper(c, tp, pick_pts, P.WOOD, rng, rim=EDGE, amp=0.15)
    facet(c, tp, [(0.0, -0.4), (0.18, -0.4), (0.18, 3.2), (0.0, 3.2)], P.WOOD_DARK)
    paper(c, tp, head_pts, P.STEEL, rng, rim=EDGE, amp=0.2)
    facet(c, tp, [(-1.9, 2.75), (-0.6, 2.95), (0.0, 2.8), (0.0, 3.1)], mix(P.STEEL, "#ffffff", 0.25))
    parts["pick"] = (c, pivot)

    shovel = [(-0.15, -0.5), (0.15, -0.5), (0.15, 2.4), (-0.15, 2.4)]
    blade = [(-0.75, 2.3), (0.75, 2.3), (0.7, 3.4), (0.0, 3.9), (-0.7, 3.4)]
    c, tp, pivot = part_canvas(shovel + blade + [(-0.6, -0.9), (0.6, -0.9)], fiber)
    paper(c, tp, [(-0.55, -0.9), (0.55, -0.9), (0.45, -0.45), (-0.45, -0.45)], P.WOOD_LIGHT, rng, amp=0.1)
    paper(c, tp, shovel, P.WOOD, rng, rim=EDGE, amp=0.12)
    paper(c, tp, blade, P.STEEL, rng, rim=EDGE, amp=0.2)
    facet(c, tp, [(0.0, 2.3), (0.75, 2.3), (0.7, 3.4), (0.0, 3.9)], mix(P.STEEL, "#000000", 0.18))
    parts["shovel"] = (c, pivot)

    # Rozevřený deštník: rukojeť nahoru (osa −y), stříška se střídavými plochami.
    handle = [(-0.1, 0.4), (0.1, 0.4), (0.1, -4.6), (-0.1, -4.6)]
    canopy = [(-3.6, -4.1)]
    for k in range(9):
        a = math.pi + k * math.pi / 8
        canopy.append((math.cos(a) * 3.6, -4.1 + math.sin(a) * 1.9))
    scallop = []
    for k in range(6):
        x0 = -3.6 + k * 1.2
        scallop += [(x0 + 1.2, -4.1), (x0 + 0.6, -3.75)]
    canopy_full = canopy + list(reversed(scallop))
    c, tp, pivot = part_canvas(canopy_full + handle + [(0.7, 0.8), (-3.8, -6.2)], fiber)
    paper(c, tp, handle, P.INK, rng, amp=0.05)
    hook = ellipse(0.35, 0.45, 0.35, 0.3, 16)
    paper(c, tp, hook, P.INK, rng, amp=0.05, shadow=False)
    paper(c, tp, canopy_full, P.JACKET, rng, rim=EDGE, amp=0.25)
    for k in range(6):
        x0 = -3.6 + k * 1.2
        top_a = math.pi + (k + 0.5) / 6 * math.pi
        apex = (0.0, -6.0)
        col = P.JACKET_LIGHT if k % 2 == 0 else P.JACKET_DARK
        tri = [apex, (x0, -4.1), (x0 + 0.6, -3.75), (x0 + 1.2, -4.1)]
        if k in (0, 5):
            tri = [apex, (x0, -4.1) if k == 0 else (x0, -4.1), (x0 + 0.6, -3.75), (x0 + 1.2, -4.1)]
        facet(c, tp, tri, col)
        crease(c, tp, apex, (x0, -4.1), "#0d3437", 0.35, 1.2)
    paper(c, tp, ellipse(0.0, -6.05, 0.22, 0.22, 12), P.CAP, rng, shadow=False, amp=0.05)
    parts["umbrella_open"] = (c, pivot)

    folded = [(-0.1, 0.4), (0.1, 0.4), (0.12, -1.0), (0.5, -1.4), (0.1, -4.2), (-0.1, -4.2), (-0.45, -1.4),
              (-0.12, -1.0)]
    c, tp, pivot = part_canvas(folded + [(0.7, 0.8), (-0.7, -4.4)], fiber)
    paper(c, tp, hook, P.INK, rng, amp=0.05, shadow=False)
    paper(c, tp, folded, P.JACKET, rng, rim=EDGE, amp=0.1)
    facet(c, tp, [(0.0, -1.0), (0.12, -1.0), (0.5, -1.4), (0.1, -4.2), (0.0, -4.2)], P.JACKET_DARK)
    parts["umbrella_closed"] = (c, pivot)

    # Papírová cihla: složený čtverec s úhlopříčným přehybem (drží se v dlani).
    brick = [(-1.0, 0.0), (1.0, 0.0), (1.0, 1.3), (-1.0, 1.3)]
    c, tp, pivot = part_canvas(brick + [(1.2, 1.5), (-1.2, -0.2)], fiber)
    paper(c, tp, brick, P.STAIR_LIGHT, rng, rim=EDGE, amp=0.12)
    facet(c, tp, [(1.0, 0.0), (1.0, 1.3), (-1.0, 1.3)], P.STAIR_MID)
    crease(c, tp, (1.0, 0.0), (-1.0, 1.3), P.STAIR_DARK, 0.6)
    parts["brick"] = (c, pivot)
    return parts


# --- kostra a pořadí kreslení ------------------------------------------------
# kloub = poloha pivotu dílu v souřadnicích rodiče (bez rotace rodiče).
SKELETON = {
    "root": {"parent": "", "joint": [0.0, 0.0]},
    "leg_back": {"parent": "root", "joint": [-0.35, -2.1], "part": "leg", "shade": 0.78},
    "arm_back": {"parent": "torso", "joint": [-0.05, -2.35], "part": "arm", "shade": 0.72},
    "torso": {"parent": "root", "joint": [0.0, -2.1], "part": "torso"},
    "leg_front": {"parent": "root", "joint": [0.35, -2.1], "part": "leg"},
    "head": {"parent": "torso", "joint": [0.15, -2.55], "part": "head"},
    "cap": {"parent": "head", "joint": [0.1, -2.25], "part": "cap"},
    "tool": {"parent": "arm_front", "joint": [0.0, 2.3], "part": ""},
    "arm_front": {"parent": "torso", "joint": [0.25, -2.3], "part": "arm"},
}
DRAW_ORDER = ["arm_back", "leg_back", "leg_front", "torso", "head", "cap", "tool", "arm_front"]
TOOL_BEHIND_ARM = True


def pose(**kw):
    return kw


# Animace: cyklus v ticích, klíče (t 0..1, pose, root=[dx, dy, rot, sx, sy], tool).
ANIMS = {
    "walk": {"cycle": 8, "loop": True, "keys": [
        (0.0, pose(leg_front=-26, leg_back=24, arm_front=34, arm_back=-34, torso=4, head=-2, cap=-2),
         [0, 0.18, 0, 1, 1]),
        (0.25, pose(leg_front=0, leg_back=0, arm_front=0, arm_back=0, torso=6, head=0, cap=3), [0, -0.12, 0, 1, 1]),
        (0.5, pose(leg_front=24, leg_back=-26, arm_front=-34, arm_back=34, torso=4, head=2, cap=-2),
         [0, 0.18, 0, 1, 1]),
        (0.75, pose(leg_front=0, leg_back=0, arm_front=0, arm_back=0, torso=6, head=0, cap=3), [0, -0.12, 0, 1, 1]),
    ]},
    "fall": {"cycle": 6, "loop": True, "keys": [
        (0.0, pose(leg_front=-14, leg_back=16, arm_front=-150, arm_back=145, torso=-3, head=-6, cap=-10),
         [0, 0, 0, 1, 1]),
        (0.5, pose(leg_front=10, leg_back=-8, arm_front=-125, arm_back=165, torso=3, head=4, cap=8),
         [0, -0.1, 0, 1, 1]),
    ]},
    "fall_umbrella": {"cycle": 6, "loop": True, "tool": "umbrella_closed", "keys": [
        (0.0, pose(leg_front=-14, leg_back=16, arm_front=205, arm_back=145, torso=-3, head=-6, cap=-10, tool=155),
         [0, 0, 0, 1, 1]),
        (0.5, pose(leg_front=10, leg_back=-8, arm_front=198, arm_back=165, torso=3, head=4, cap=8, tool=166),
         [0, -0.1, 0, 1, 1]),
    ]},
    # Lezec je přitisknutý ke stěně vpravo: obě ruce vpředu nahoře, kolena střídavě nahoru.
    "climb": {"cycle": 8, "loop": True, "keys": [
        (0.0, pose(leg_front=-70, leg_back=-20, arm_front=-158, arm_back=-128, torso=14, head=-12, cap=-6),
         [0.55, 0, -4, 1, 1]),
        (0.5, pose(leg_front=-20, leg_back=-70, arm_front=-128, arm_back=-158, torso=14, head=-12, cap=0),
         [0.55, -0.2, -4, 1, 1]),
    ]},
    "float": {"cycle": 20, "loop": True, "tool": "umbrella_open", "unfold_ticks": 5, "keys": [
        (0.0, pose(leg_front=-8, leg_back=10, arm_front=202, arm_back=24, torso=-2, head=-4, cap=-3, tool=158),
         [0, 0, -3, 1, 1]),
        (0.5, pose(leg_front=8, leg_back=-6, arm_front=198, arm_back=8, torso=2, head=2, cap=4, tool=164),
         [0, 0, 3, 1, 1]),
    ]},
    "block": {"cycle": 24, "loop": True, "keys": [
        (0.0, pose(leg_front=-17, leg_back=17, arm_front=-100, arm_back=100, torso=0, head=0, cap=0),
         [0, 0.12, 0, 1, 1]),
        (0.5, pose(leg_front=-17, leg_back=17, arm_front=-88, arm_back=88, torso=-1, head=-3, cap=-3),
         [0, 0.0, 0, 1, 1]),
    ]},
    # Stavitel: kontakt (položení cihly) v t = 0.5 ↔ SimConst.BUILDER_BRICK_PHASE.
    "build": {"cycle": 16, "loop": True, "tool": "brick", "keys": [
        (0.0, pose(leg_front=-6, leg_back=8, arm_front=30, arm_back=-10, torso=4, head=0, cap=0, tool=-30),
         [0, 0, 0, 1, 1], "brick"),
        (0.25, pose(leg_front=-24, leg_back=14, arm_front=-55, arm_back=-45, torso=30, head=-10, cap=-4, tool=40),
         [0, 0.35, 0, 1, 1], "brick"),
        (0.5, pose(leg_front=-30, leg_back=16, arm_front=-72, arm_back=-62, torso=38, head=-14, cap=-6, tool=70),
         [0, 0.45, 0, 1, 1], ""),
        (0.75, pose(leg_front=-20, leg_back=6, arm_front=-20, arm_back=-10, torso=14, head=-4, cap=2, tool=0),
         [0, 0.12, 0, 1, 1], ""),
    ]},
    # Razič: úder v t = 0 ↔ tik, kdy se maže stěna (state_ticks % 8 == 0).
    "bash": {"cycle": 8, "loop": True, "tool": "pick", "keys": [
        (0.0, pose(leg_front=-20, leg_back=18, arm_front=262, arm_back=255, torso=14, head=-6, cap=-4, tool=0),
         [0, 0.12, 0, 1, 1]),
        (0.18, pose(leg_front=-20, leg_back=18, arm_front=248, arm_back=242, torso=10, head=-4, cap=0, tool=0),
         [0, 0.12, 0, 1, 1]),
        (0.6, pose(leg_front=-14, leg_back=14, arm_front=160, arm_back=150, torso=-8, head=4, cap=4, tool=-10),
         [0, 0.0, 0, 1, 1]),
        (0.85, pose(leg_front=-18, leg_back=16, arm_front=205, arm_back=198, torso=2, head=0, cap=0, tool=0),
         [0, 0.06, 0, 1, 1]),
    ]},
    # Horník: úder šikmo dolů dopředu, kontakt v t = 0 (state_ticks % 8 == 0).
    "mine": {"cycle": 8, "loop": True, "tool": "pick", "keys": [
        (0.0, pose(leg_front=-24, leg_back=20, arm_front=300, arm_back=292, torso=26, head=-10, cap=-6, tool=0),
         [0, 0.3, 0, 1, 1]),
        (0.2, pose(leg_front=-22, leg_back=20, arm_front=290, arm_back=282, torso=22, head=-8, cap=-2, tool=0),
         [0, 0.28, 0, 1, 1]),
        (0.6, pose(leg_front=-14, leg_back=14, arm_front=170, arm_back=160, torso=-4, head=4, cap=4, tool=-10),
         [0, 0.05, 0, 1, 1]),
        (0.85, pose(leg_front=-18, leg_back=16, arm_front=230, arm_back=222, torso=10, head=0, cap=0, tool=0),
         [0, 0.15, 0, 1, 1]),
    ]},
    # Kopáč: lopata dolů (kontakt v t = 0), zvednutí výkopu v t = 0.5.
    "dig": {"cycle": 8, "loop": True, "tool": "shovel", "keys": [
        (0.0, pose(leg_front=-26, leg_back=22, arm_front=-18, arm_back=-8, torso=28, head=-12, cap=-6, tool=8),
         [0, 0.4, 0, 1, 1]),
        (0.5, pose(leg_front=-20, leg_back=18, arm_front=-62, arm_back=-50, torso=18, head=-4, cap=2, tool=30),
         [0, 0.25, 0, 1, 1]),
    ]},
    "shrug": {"cycle": 8, "loop": False, "keys": [
        (0.0, pose(leg_front=0, leg_back=0, arm_front=-20, arm_back=20, torso=0, head=0, cap=0), [0, 0, 0, 1, 1]),
        (0.45, pose(leg_front=-4, leg_back=4, arm_front=-128, arm_back=128, torso=-2, head=-12, cap=-14),
         [0, -0.15, 0, 1, 1]),
        (1.0, pose(leg_front=-4, leg_back=4, arm_front=-118, arm_back=118, torso=-2, head=-10, cap=-10),
         [0, -0.1, 0, 1, 1]),
    ]},
    "splat": {"cycle": 16, "loop": False, "keys": [
        (0.0, pose(leg_front=-30, leg_back=30, arm_front=-120, arm_back=120, torso=0, head=0, cap=-20),
         [0, 0, 0, 1.15, 0.8]),
        (0.25, pose(leg_front=-70, leg_back=70, arm_front=-95, arm_back=95, torso=0, head=10, cap=-40),
         [0, 0, 0, 1.55, 0.3]),
        (1.0, pose(leg_front=-80, leg_back=80, arm_front=-90, arm_back=90, torso=0, head=12, cap=-55),
         [0, 0, 0, 1.7, 0.22]),
    ]},
    "exit": {"cycle": 10, "loop": False, "keys": [
        (0.0, pose(leg_front=-14, leg_back=12, arm_front=-150, arm_back=10, torso=2, head=-6, cap=-6),
         [0, 0, 0, 1, 1]),
        (0.5, pose(leg_front=10, leg_back=-10, arm_front=-170, arm_back=-10, torso=-2, head=4, cap=6),
         [0.2, -0.2, 0, 0.85, 0.85]),
        (1.0, pose(leg_front=0, leg_back=0, arm_front=-160, arm_back=0, torso=0, head=0, cap=0),
         [0.5, -0.1, 0, 0.55, 0.55]),
    ]},
}
# Stav simulace → animace (Lemming.State v pořadí výčtu).
STATE_ANIMS = ["fall", "walk", "splat", "exit", "block", "build", "shrug", "bash", "dig", "climb", "float", "mine"]


def pack(parts):
    """Jednoduché řádkové balení dílů do atlasu (šířka 1024)."""
    order = sorted(parts.items(), key=lambda kv: -kv[1][0].h)
    x = y = row_h = 0
    width = 1024
    placed = {}
    for name, (c, pivot) in order:
        if x + c.w > width:
            x = 0
            y += row_h + 2
            row_h = 0
        placed[name] = (x, y, c, pivot)
        x += c.w + 2
        row_h = max(row_h, c.h)
    height = y + row_h
    height = 1 << (height - 1).bit_length()
    atlas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    meta = {}
    for name, (px, py, c, pivot) in placed.items():
        atlas.alpha_composite(c.image(), (px, py))
        meta[name] = {"region": [px, py, c.w, c.h], "pivot": [round(pivot[0], 2), round(pivot[1], 2)]}
    return atlas, meta


# --- náhled: stejný výpočet jako view/paper_actors.gd --------------------------
def sample(anim, t):
    keys = anim["keys"]
    if anim["loop"]:
        t %= 1.0
    else:
        t = min(max(t, 0.0), 1.0)
    for i, key in enumerate(keys):
        nxt = keys[i + 1] if i + 1 < len(keys) else None
        if nxt is None:
            if not anim["loop"]:
                return key[1], key[2], key[3] if len(key) > 3 else None
            nxt = (keys[0][0] + 1.0,) + tuple(keys[0][1:])
        if key[0] <= t < nxt[0]:
            f = (t - key[0]) / (nxt[0] - key[0])
            f = 0.5 - 0.5 * math.cos(math.pi * f)
            pose_out = {k: key[1].get(k, 0) + (nxt[1].get(k, 0) - key[1].get(k, 0)) * f for k in
                        set(key[1]) | set(nxt[1])}
            root = [a + (b - a) * f for a, b in zip(key[2], nxt[2])]
            return pose_out, root, key[3] if len(key) > 3 else None
    key = keys[0]
    return key[1], key[2], key[3] if len(key) > 3 else None


def world_transforms(pose_angles, root):
    dx, dy, rot, sx, sy = root
    mats = {}

    def mat(tx, ty, deg, scx=1.0, scy=1.0):
        a = math.radians(deg)
        return np.array([[math.cos(a) * scx, -math.sin(a) * scy, tx],
                         [math.sin(a) * scx, math.cos(a) * scy, ty], [0, 0, 1]])
    mats["root"] = mat(dx, dy, rot, sx, sy)

    def resolve(name):
        if name in mats:
            return mats[name]
        node = SKELETON[name]
        parent = resolve(node["parent"])
        jx, jy = node["joint"]
        mats[name] = parent @ mat(jx, jy, pose_angles.get(name, 0.0))
        return mats[name]
    for name in SKELETON:
        resolve(name)
    return mats


def render_pose(atlas, meta, anim_name, t, scale=12):
    anim = ANIMS[anim_name]
    angles, root, tool_override = sample(anim, t)
    mats = world_transforms(angles, root)
    size = 16 * scale
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    origin = np.array([[scale, 0, size * 0.5], [0, scale, size * 0.78], [0, 0, 1]])
    tool = anim.get("tool", "") if tool_override is None else tool_override
    for name in DRAW_ORDER:
        part = SKELETON[name].get("part", "")
        if name == "tool":
            part = tool
        if not part:
            continue
        x, y, w, h = meta[part]["region"]
        px, py = meta[part]["pivot"]
        tile = atlas.crop((x, y, x + w, y + h))
        if SKELETON[name].get("shade"):
            k = SKELETON[name]["shade"]
            arr = np.asarray(tile, np.float32)
            arr[..., :3] *= k
            tile = Image.fromarray(arr.astype(np.uint8), "RGBA")
        local = np.array([[1 / A, 0, -px / A], [0, 1 / A, -py / A], [0, 0, 1]])
        m = origin @ mats[name] @ local
        inv = np.linalg.inv(m)
        warped = tile.transform((size, size), Image.AFFINE, tuple(inv[:2].reshape(-1)), Image.BICUBIC)
        img.alpha_composite(warped)
    return img


def contact_sheet(atlas, meta, path: Path):
    names = list(ANIMS)
    cols = 8
    cell = 16 * 12
    sheet = Image.new("RGBA", (cell * cols, cell * len(names)), (196, 214, 210, 255))
    for row, name in enumerate(names):
        for col in range(cols):
            t = col / cols if ANIMS[name]["loop"] else col / (cols - 1)
            sheet.alpha_composite(render_pose(atlas, meta, name, t), (col * cell, row * cell))
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)


def build(out: Path, seed: int = 2028):
    fiber = fiber_field(256, 256, np.random.default_rng(seed), fibers=260, scale=0.6)
    parts = make_parts(fiber, np.random.default_rng(seed + 1))
    atlas, meta = pack(parts)
    (out / "actor").mkdir(parents=True, exist_ok=True)
    atlas.save(out / "actor" / "worker_atlas.png", optimize=True)
    anims = {}
    for name, anim in ANIMS.items():
        keys = []
        for key in anim["keys"]:
            entry = {"t": key[0], "pose": key[1], "root": key[2]}
            if len(key) > 3:
                entry["tool"] = key[3]
            keys.append(entry)
        anims[name] = {"cycle": anim["cycle"], "loop": anim["loop"], "tool": anim.get("tool", ""),
                       "unfold_ticks": anim.get("unfold_ticks", 0), "keys": keys}
    rig = {
        "units": "logical simulation pixels; y down; facing +x; degrees clockwise",
        "atlas": "actor/worker_atlas.png", "atlas_scale": A,
        "parts": meta, "skeleton": SKELETON, "draw_order": DRAW_ORDER,
        "animations": anims, "state_animations": STATE_ANIMS,
        "blend_ticks": 3,
    }
    (out / "actor" / "worker_rig.json").write_text(json.dumps(rig, indent=1, ensure_ascii=False) + "\n")
    contact_sheet(atlas, meta, out / "source" / "previews" / "worker_poses.png")


if __name__ == "__main__":
    build(Path(__file__).resolve().parents[1])
