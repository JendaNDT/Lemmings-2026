"""Ikona aplikace Paperlings: origami postavička kráčí po papírovém kopci.

Postavička se skládá ze stejných dílů a pózy chůze jako ve hře (build_character),
jen ve trojnásobném rozlišení. Výstup ve složce icon/:

- icon_1024.png – celá ikona se zaoblenými rohy (macOS, náhledy, vydání),
- icon_256.png – ikona projektu a okna hry,
- android_192.png – klasická ikona Androidu,
- android_bg_432.png a android_fg_432.png – adaptivní ikona Androidu
  (pozadí s krajinou a postavička zvlášť; postavička leží v bezpečném kruhu),
- paperlings.ico (Windows, 16–256 px) a paperlings.icns (macOS).
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

import build_character as BC
import palette as P
from paperlib import Canvas, ellipse, fiber_field, tear

SIZE = 1024
FIGURE_A = 96  # pixelů dílu na logický pixel (hra má 32)
FIGURE_SCALE = 74  # pixelů ikony 1024 na logický pixel postavy
ICO_SIZES = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]


def figure(scale: float, seed: int = 2028) -> Image.Image:
    """Postavička v póze chůze; nohy stojí v bodě (size/2, 0,78·size), size = 16·scale."""
    saved = BC.A, BC.PAD, BC.SHADOW
    BC.A = FIGURE_A
    BC.PAD = 30
    BC.SHADOW = (0.13 * BC.A, 0.16 * BC.A, 7.8, 0.4)
    try:
        fiber = fiber_field(256, 256, np.random.default_rng(seed), fibers=260, scale=0.6)
        parts = BC.make_parts(fiber, np.random.default_rng(seed + 1))
        atlas, meta = BC.pack(parts)
        return BC.render_pose(atlas, meta, "walk", 0.0, scale=scale)
    finally:
        BC.A, BC.PAD, BC.SHADOW = saved


def scene(size: int, seed: int = 2031) -> Image.Image:
    """Pozadí: obloha se sluncem, vzdálený modrý a blízký zelený papírový kopec."""
    fiber = fiber_field(256, 256, np.random.default_rng(seed), fibers=220, scale=0.6)
    rng = np.random.default_rng(seed + 1)
    k = size / SIZE
    c = Canvas(size, size, fiber=fiber)
    c.shape([(0, 0), (size, 0), (size, size), (0, size)], P.SKY_TOP, fiber=0.05,
            gradient=(P.SKY_HORIZON, 0, size * 0.75))
    c.shape(tear(ellipse(835 * k, 175 * k, 105 * k, 105 * k, n=64), 2.0 * k, rng, step=4), P.SUN,
            fiber=0.06, bevel=(4.0 * k, 0.3, 0.2))
    c.shape(tear([(-40 * k, 690 * k), (200 * k, 590 * k), (430 * k, 640 * k), (700 * k, 560 * k),
                  (1064 * k, 640 * k), (1064 * k, 1064 * k), (-40 * k, 1064 * k)], 3.0 * k, rng,
                 step=5), P.HILL_BLUE, fiber=0.07, shadow=(0, 6 * k, 8 * k, 0.25),
            bevel=(4.0 * k, 0.25, 0.2))
    hill = [(-40 * k, 800 * k), (240 * k, 760 * k), (520 * k, 790 * k), (800 * k, 750 * k),
            (1064 * k, 790 * k), (1064 * k, 1064 * k), (-40 * k, 1064 * k)]
    c.shape(tear(hill, 3.0 * k, rng, step=5), P.GRASS, fiber=0.08, shadow=(0, 8 * k, 10 * k, 0.3),
            gradient=(P.GRASS_DARK, 760 * k, 1024 * k), bevel=(5.0 * k, 0.35, 0.2))
    c.crease((60 * k, 830 * k), (420 * k, 812 * k), 3.0 * k, P.GRASS_TOP, 0.5)
    c.crease((600 * k, 830 * k), (980 * k, 808 * k), 3.0 * k, P.GRASS_TOP, 0.5)
    return c.image()


def rounded(img: Image.Image, margin: float, radius: float) -> Image.Image:
    """Ikona se zaoblenými rohy a průhledným okrajem (vyhlazeno 4× převzorkováním)."""
    size = img.width
    big = Image.new("L", (size * 4, size * 4), 0)
    ImageDraw.Draw(big).rounded_rectangle(
        (margin * 4, margin * 4, (size - margin) * 4 - 1, (size - margin) * 4 - 1),
        radius=radius * 4, fill=255)
    mask = big.resize((size, size), Image.LANCZOS)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    body = img.resize((size - 2 * int(margin),) * 2, Image.LANCZOS)
    out.paste(body, (int(margin), int(margin)))
    out.putalpha(Image.fromarray(np.minimum(np.asarray(out)[..., 3], np.asarray(mask))))
    return out


def composite(size: int) -> Image.Image:
    """Krajina s postavičkou (čtverec bez zaoblení)."""
    img = scene(size)
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse((size * 0.34, size * 0.765, size * 0.64, size * 0.805),
                                   fill=(20, 40, 30, 70))
    img.alpha_composite(shadow)
    person = figure(FIGURE_SCALE * size // SIZE)
    # Postavička stojí na kopci (nohy v 0,785 výšky) uprostřed ikony.
    img.alpha_composite(person, (round(size / 2 - person.width / 2),
                                 round(0.785 * size - 0.78 * person.height)))
    return img


def build(out: Path) -> None:
    folder = out / "icon"
    folder.mkdir(parents=True, exist_ok=True)
    full = composite(SIZE)
    icon = rounded(full, margin=40, radius=200)
    icon.save(folder / "icon_1024.png", optimize=True)
    icon.resize((256, 256), Image.LANCZOS).save(folder / "icon_256.png", optimize=True)
    rounded(full, margin=0, radius=180).resize((192, 192), Image.LANCZOS).save(
        folder / "android_192.png", optimize=True)
    scene(432).save(folder / "android_bg_432.png", optimize=True)
    # Adaptivní popředí: postavička zmenšená do bezpečného kruhu (průměr 264 z 432).
    person = figure(64)
    box = person.getbbox()
    crop = person.crop(box)
    height = 220
    width = round(crop.width * height / crop.height)
    small = crop.resize((width, height), Image.LANCZOS)
    fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    fg.alpha_composite(small, ((432 - width) // 2, (432 - height) // 2))
    fg.save(folder / "android_fg_432.png", optimize=True)
    icon.save(folder / "paperlings.ico", sizes=ICO_SIZES)
    icon.save(folder / "paperlings.icns")


if __name__ == "__main__":
    build(Path(__file__).resolve().parents[1])
