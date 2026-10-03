"""Papírové prvky HUDu: panely pro StyleBoxTexture (9 dílů) a ikony dovedností (SVG).

Panely mají vláknitou texturu, mírně nepravidelný stříhaný okraj a měkký stín.
Ikony jsou ručně psané SVG siluety (inkoust na slonovinové dlaždici), lze je
upravit v libovolném textovém nebo vektorovém editoru.
"""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np

import palette as P
from paperlib import Canvas, fiber_field, mix, tear

SHADOW = (3, 5, 4, 0.35)


def panel(name, w, h, color, fiber, rng, out: Path, margin: int, *, radius=6, edge=None, amp=0.8,
          shadow=SHADOW, fiber_k=0.08, inner=None):
    pad = 12
    c = Canvas(w + pad * 2, h + pad * 2, fiber=fiber)
    x0, y0, x1, y1 = pad, pad, pad + w, pad + h
    pts = [(x0 + radius, y0), (x1 - radius, y0), (x1, y0 + radius), (x1, y1 - radius), (x1 - radius, y1),
           (x0 + radius, y1), (x0, y1 - radius), (x0, y0 + radius)]
    if edge is not None:
        c.shape(tear(pts, amp, rng, step=4), edge, fiber=fiber_k, shadow=shadow)
        inset = 3
        pts2 = [(x0 + radius + inset, y0 + inset), (x1 - radius - inset, y0 + inset), (x1 - inset, y0 + radius + inset),
                (x1 - inset, y1 - radius - inset), (x1 - radius - inset, y1 - inset), (x0 + radius + inset, y1 - inset),
                (x0 + inset, y1 - radius - inset), (x0 + inset, y0 + radius + inset)]
        c.shape(tear(pts2, amp * 0.6, rng, step=4), color, fiber=fiber_k)
    else:
        c.shape(tear(pts, amp, rng, step=4), color, fiber=fiber_k, shadow=shadow)
    if inner:
        # Jemný světlý přehyb podél horní hrany (lom papíru).
        c.crease((x0 + radius + 4, y0 + 7), (x1 - radius - 4, y0 + 7), 1.5, inner, 0.35)
    c.save(out / "ui" / f"{name}.png")
    return {"file": f"ui/{name}.png", "margin": margin + pad}


ICONS = {
    # Lezec: postavička s čepicí šplhá po stěně.
    "climber": """<rect x="44" y="6" width="9" height="52" rx="1.5"/>
<path d="M22 20 L31 11 L40 20 Z"/>
<rect x="26" y="20" width="10" height="9" rx="2"/>
<path d="M24 30 L37 30 L39 45 L23 45 Z"/>
<path d="M35 31 L43 22 L45.5 24.5 L38 34 Z"/>
<path d="M24 32 L17 26 L19 23.5 L27 29 Z"/>
<path d="M27 44 L33 44 L42 51 L39.5 54 L31 48 L29 55 L24 55 Z"/>""",
    # Padák: deštník se zoubkovaným okrajem a háčkem.
    "floater": """<path d="M6 32 C8 16 20 8 32 8 C44 8 56 16 58 32 C55 29 51 29 48.5 32 C45.5 29 41.5 29 38.7 32 C35.7 29 31.7 29 29 32 C26 29 22 29 19.2 32 C16.3 29 12 29 9.6 32 Z"/>
<rect x="30.5" y="30" width="3" height="20"/>
<path d="M30.5 48 L33.5 48 C33.5 56 23 56 23.5 50 L26.5 50 C26.5 52.5 30.5 52.5 30.5 48 Z"/>""",
    # Bombič: koule s doutnákem a jiskrou.
    "bomber": """<circle cx="28" cy="38" r="17"/>
<rect x="34" y="15" width="9" height="8" rx="1.5" transform="rotate(35 38.5 19)"/>
<path d="M41 15 C43 10 46 9 49 10" fill="none" stroke="#15333a" stroke-width="2.6" stroke-linecap="round"/>
<path d="M52 4 L53.6 8.4 L58 7 L55 10.6 L59 13 L54.4 13.2 L54 18 L51.6 14 L47.6 16 L49.4 11.8 L45.4 9.4 L50 9.2 Z"/>
<path d="M18 32 C19 27 23 24 27 23.5" fill="none" stroke="#ecdcc0" stroke-width="3" stroke-linecap="round" opacity="0.7"/>""",
    # Blokař: postava zpředu s rozpaženýma rukama.
    "blocker": """<path d="M23 14 L32 4 L41 14 Z"/>
<rect x="26.5" y="14" width="11" height="10" rx="2"/>
<path d="M24.5 25 L39.5 25 L41 43 L23 43 Z"/>
<path d="M24 26 L6 22 L5 27.5 L24 32 Z"/>
<path d="M40 26 L58 22 L59 27.5 L40 32 Z"/>
<path d="M24 42 L31 42 L30 58 L24 58 Z"/>
<path d="M33 42 L40 42 L40 58 L34 58 Z"/>""",
    # Stavitel: schody stoupající doprava.
    "builder": """<path d="M6 56 L6 46 L18 46 L18 36 L30 36 L30 26 L42 26 L42 16 L58 16 L58 26 L46 26 L46 36 L34 36 L34 46 L22 46 L22 56 Z"/>
<path d="M42 16 L48 10 L58 10 L58 16 Z" opacity="0.55"/>""",
    # Razič: velký krumpáč míří vodorovně do stěny, odletují úlomky.
    "basher": """<rect x="47" y="6" width="11" height="52" rx="1.5"/>
<rect x="4" y="29" width="34" height="6.5" rx="2.5"/>
<path d="M30 8 C36 14 39 22 40 32 C39 42 36 50 30 56 L36 56 C42 50 45.5 42 46 32 C45.5 22 42 14 36 8 Z"/>
<path d="M14 46 L19 43 L20 49 Z"/>
<path d="M8 52 L12 50 L13 55 Z"/>
<path d="M20 54 L24 52 L24 57 Z"/>""",
    # Horník: šikmý tunel dolů s krumpáčem.
    "miner": """<path d="M4 18 L60 50 L60 60 L4 60 Z"/>
<rect x="22" y="3" width="6.5" height="30" rx="2.5" transform="rotate(-35 25 18)"/>
<path d="M30 2 C38 3 46 8 50 15 L45 17 C42 12 37 9 31 8 Z"/>
<path d="M44 32 L49 30 L49 35 Z"/>
<path d="M52 37 L56 36 L56 41 Z"/>""",
    # Kopáč: přerušované šipky svisle dolů.
    "digger": """<rect x="14" y="4" width="5" height="7" rx="1"/>
<rect x="14" y="15" width="5" height="7" rx="1"/>
<rect x="14" y="26" width="5" height="7" rx="1"/>
<path d="M8 37 L25 37 L16.5 50 Z"/>
<rect x="38" y="10" width="5" height="7" rx="1"/>
<rect x="38" y="21" width="5" height="7" rx="1"/>
<path d="M32 32 L49 32 L40.5 45 Z"/>
<rect x="6" y="54" width="52" height="5" rx="1.5"/>""",
    # Zvuk zapnutý: reproduktor a dvě vlnky.
    "sound_on": """<path d="M8 24 L18 24 L31 12 L31 52 L18 40 L8 40 Z"/>
<path d="M38 24 C42 28 42 36 38 40" fill="none" stroke="currentColor" stroke-width="4.5" stroke-linecap="round"/>
<path d="M45 16 C53 24 53 40 45 48" fill="none" stroke="currentColor" stroke-width="4.5" stroke-linecap="round"/>""",
    # Zvuk vypnutý: reproduktor a křížek.
    "sound_off": """<path d="M8 24 L18 24 L31 12 L31 52 L18 40 L8 40 Z"/>
<path d="M39 23 L55 41 M55 23 L39 41" fill="none" stroke="currentColor" stroke-width="5" stroke-linecap="round"/>""",
}


def write_icons(out: Path):
    folder = out / "ui" / "icons"
    folder.mkdir(parents=True, exist_ok=True)
    for name, body in ICONS.items():
        svg = ('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64" '
               f'color="{P.ICON_INK}" fill="{P.ICON_INK}">\n{body}\n</svg>\n')
        (folder / f"{name}.svg").write_text(svg)


def build(out: Path, seed: int = 2029):
    fiber = fiber_field(256, 256, np.random.default_rng(seed), fibers=220, scale=0.6)
    rng = np.random.default_rng(seed + 1)
    data = {
        "toolbar": panel("toolbar", 420, 150, P.TOOLBAR, fiber, rng, out, 22, radius=22, amp=1.2,
                         inner=P.TOOLBAR_LIGHT),
        "tile": panel("tile", 120, 90, P.TILE, fiber, rng, out, 14, radius=7, amp=0.7, edge=P.TILE_SHADE),
        "tile_hover": panel("tile_hover", 120, 90, mix(P.TILE, "#ffffff", 0.35), fiber, rng, out, 14,
                            radius=7, amp=0.7, edge=P.TILE_SHADE),
        "tile_selected": panel("tile_selected", 120, 90, P.TILE_SELECTED, fiber, rng, out, 14, radius=7,
                               amp=0.7, edge=mix(P.TILE_SELECTED, "#7a4a12", 0.35)),
        "tile_disabled": panel("tile_disabled", 120, 90, mix(P.TILE, P.TOOLBAR, 0.45), fiber, rng, out, 14,
                               radius=7, amp=0.7, shadow=(2, 3, 3, 0.2)),
        "label": panel("label", 360, 70, P.TILE, fiber, rng, out, 18, radius=4, amp=1.6,
                       edge=mix(P.TILE_SHADE, P.WOOD, 0.3)),
        "dialog": panel("dialog", 420, 260, P.TILE, fiber, rng, out, 30, radius=10, amp=1.6,
                        edge=mix(P.TILE_SHADE, P.WOOD, 0.3)),
    }
    (out / "ui" / "ui.json").write_text(json.dumps(data, indent=2) + "\n")
    write_icons(out)


if __name__ == "__main__":
    build(Path(__file__).resolve().parents[1])
