"""Společné nástroje generátoru papírových podkladů.

Vše je deterministické: náhoda má pevný seed, takže stejný kód dá stejné PNG.
Tvary se kreslí jako mnohoúhelníky se 4× převzorkováním, papír dostává
periodickou vláknitou texturu, trhané okraje a jemné stíny mezi vrstvami.
"""

from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

SS = 4  # převzorkování obrysů


def rgb(value: str) -> np.ndarray:
    value = value.lstrip("#")
    return np.array([int(value[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


def mix(a, b, t: float) -> np.ndarray:
    a = rgb(a) if isinstance(a, str) else a
    b = rgb(b) if isinstance(b, str) else b
    return a * (1.0 - t) + b * t


def periodic_noise(w: int, h: int, power: float, rng: np.random.Generator,
                   cutoff: float = 0.0) -> np.ndarray:
    """Šum periodický v obou osách (filtrace bílého šumu ve frekvenční oblasti)."""
    white = rng.standard_normal((h, w))
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1.0
    amp = f ** (-power / 2.0)
    if cutoff > 0:
        amp *= np.exp(-(f / cutoff) ** 2)
    amp[0, 0] = 0.0
    out = np.real(np.fft.ifft2(np.fft.fft2(white) * amp))
    out -= out.mean()
    out /= out.std() + 1e-9
    return out


def smooth_noise_1d(n: int, rng: np.random.Generator, octaves=((24, 1.0), (7, 0.45), (2, 0.2)),
                    closed: bool = True) -> np.ndarray:
    """Hladký 1D šum pro trhané okraje; pro uzavřený tvar navazuje dokola."""
    total = np.zeros(n)
    for width, weight in octaves:
        raw = rng.standard_normal(n)
        sigma = max(width / 3.0, 0.5)
        mode = "wrap" if closed else "reflect"
        sm = ndimage.gaussian_filter1d(raw, sigma, mode=mode)
        sm /= sm.std() + 1e-9
        total += sm * weight
    return total / sum(w for _, w in octaves)


def resample(points, step: float, closed: bool = True) -> np.ndarray:
    pts = np.asarray(points, dtype=float)
    if closed:
        pts = np.vstack([pts, pts[:1]])
    out = []
    for a, b in zip(pts[:-1], pts[1:]):
        seg = b - a
        length = float(np.hypot(*seg))
        count = max(1, int(math.ceil(length / step)))
        for i in range(count):
            out.append(a + seg * (i / count))
    if not closed:
        out.append(pts[-1])
    return np.array(out)


def tear(points, amp: float, rng: np.random.Generator, step: float = 2.0,
         closed: bool = True, fine: float = 0.35) -> np.ndarray:
    """Trhaný / stříhaný okraj: posun bodů po normále hladkým i jemným šumem."""
    pts = resample(points, step, closed)
    n = len(pts)
    if n < 3:
        return pts
    nxt = np.roll(pts, -1, axis=0)
    prv = np.roll(pts, 1, axis=0)
    tangent = nxt - prv
    normal = np.stack([tangent[:, 1], -tangent[:, 0]], axis=1)
    normal /= np.linalg.norm(normal, axis=1, keepdims=True) + 1e-9
    offset = smooth_noise_1d(n, rng, closed=closed) * amp
    offset += rng.standard_normal(n) * amp * fine
    if not closed:
        offset[0] = 0
        offset[-1] = 0
    return pts + normal * offset[:, None]


def coverage(polys, box, ss: int = SS) -> np.ndarray:
    """Antialiasovaná maska krytí mnohoúhelníků v obdélníku box=(x0, y0, w, h)."""
    x0, y0, w, h = box
    img = Image.new("L", (w * ss, h * ss), 0)
    draw = ImageDraw.Draw(img)
    for poly in polys:
        if len(poly) < 3:
            continue
        p = [((x - x0) * ss, (y - y0) * ss) for x, y in poly]
        draw.polygon(p, fill=255)
    arr = np.asarray(img, dtype=np.float32).reshape(h, ss, w, ss).mean(axis=(1, 3)) / 255.0
    return arr


class Canvas:
    """Premultiplikované RGBA plátno ve float32. wrap_x = vodorovně navazující dlaždice."""

    def __init__(self, w: int, h: int, wrap_x: bool = False, fiber=None):
        self.w, self.h = w, h
        self.wrap_x = wrap_x
        self.rgb = np.zeros((h, w, 3), np.float32)
        self.a = np.zeros((h, w), np.float32)
        self.fiber = fiber  # (h, w) šum −1..1, nebo None

    # --- skládání -----------------------------------------------------------
    def _boxes(self, polys, pad: int):
        xs = np.concatenate([np.asarray(p)[:, 0] for p in polys])
        ys = np.concatenate([np.asarray(p)[:, 1] for p in polys])
        x0 = int(math.floor(xs.min())) - pad
        x1 = int(math.ceil(xs.max())) + pad
        y0 = max(int(math.floor(ys.min())) - pad, 0)
        y1 = min(int(math.ceil(ys.max())) + pad, self.h)
        return x0, y0, x1, y1

    def over(self, color, alpha: np.ndarray, x0: int, y0: int) -> None:
        """Složí obrázek (barva h×w×3 nebo jedna barva) s alfou na pozici; respektuje wrap."""
        h, w = alpha.shape
        if np.ndim(color) == 1:
            color = np.broadcast_to(np.asarray(color, np.float32), (h, w, 3))
        ys = slice(max(y0, 0), min(y0 + h, self.h))
        sy = slice(ys.start - y0, ys.stop - y0)
        if ys.stop <= ys.start:
            return
        shifts = [0]
        if self.wrap_x:
            shifts = [-self.w, 0, self.w]
        for shift in shifts:
            ax0 = x0 + shift
            xs = slice(max(ax0, 0), min(ax0 + w, self.w))
            if xs.stop <= xs.start:
                continue
            sx = slice(xs.start - ax0, xs.stop - ax0)
            a = alpha[sy, sx]
            c = color[sy, sx]
            self.rgb[ys, xs] = c * a[..., None] + self.rgb[ys, xs] * (1 - a[..., None])
            self.a[ys, xs] = a + self.a[ys, xs] * (1 - a)

    def texture(self, color, x0, y0, h, w, strength: float, tint_rng=None):
        base = np.broadcast_to(np.asarray(color, np.float32), (h, w, 3)).copy()
        if self.fiber is not None and strength > 0:
            fy = (np.arange(y0, y0 + h) % self.fiber.shape[0])
            fx = (np.arange(x0, x0 + w) % self.fiber.shape[1])
            f = self.fiber[np.ix_(fy, fx)]
            base *= (1.0 + strength * f)[..., None]
        if tint_rng is not None:
            base *= 1.0 + tint_rng.uniform(-0.035, 0.035)
        return np.clip(base, 0, 1)

    def shape(self, polys, color, *, fiber: float = 0.06, shadow=None, rim=None,
              tint_rng=None, gradient=None) -> np.ndarray:
        """Vystřižený tvar. shadow=(dx, dy, rozostření, krytí), rim=(šířka, barva, krytí).

        gradient=(barva_dole, y_od, y_do) jemně přechází barvu svisle.
        Vrací masku krytí v rámci obdélníku (pro další úpravy)."""
        if isinstance(polys, np.ndarray) or (polys and np.ndim(polys[0]) == 1):
            polys = [polys]
        color = rgb(color) if isinstance(color, str) else np.asarray(color)
        pad = 4
        if shadow:
            pad += int(abs(shadow[0]) + abs(shadow[1]) + shadow[2] * 3) + 2
        x0, y0, x1, y1 = self._boxes(polys, pad)
        w, h = x1 - x0, y1 - y0
        if w <= 0 or h <= 0:
            return np.zeros((1, 1))
        cov = coverage(polys, (x0, y0, w, h))
        if shadow:
            dx, dy, blur, opacity = shadow
            sh = ndimage.shift(cov, (dy, dx), order=1, mode="constant")
            if blur > 0:
                sh = ndimage.gaussian_filter(sh, blur)
            self.over(np.zeros(3, np.float32), sh * opacity, x0, y0)
        if rim:
            width, rim_color, rim_alpha = rim
            grown = ndimage.grey_dilation(cov, size=(int(width * 2 + 1),) * 2)
            grown = ndimage.gaussian_filter(grown, 0.6)
            rc = rgb(rim_color) if isinstance(rim_color, str) else rim_color
            self.over(self.texture(rc, x0, y0, h, w, fiber * 1.5), grown * rim_alpha, x0, y0)
        tex = self.texture(color, x0, y0, h, w, fiber, tint_rng)
        if gradient is not None:
            low, ga, gb = gradient
            low = rgb(low) if isinstance(low, str) else low
            t = np.clip((np.arange(y0, y1) - ga) / max(gb - ga, 1), 0, 1)[:, None, None]
            tex = tex * (1 - t) + self.texture(low, x0, y0, h, w, fiber) * t
        self.over(tex, cov, x0, y0)
        return cov

    def crease(self, a, b, width: float, color, alpha: float) -> None:
        """Rýha přehybu: tenká čára (světlá nebo tmavá)."""
        ax, ay = a
        bx, by = b
        dx, dy = bx - ax, by - ay
        length = math.hypot(dx, dy) + 1e-9
        nx, ny = -dy / length * width / 2, dx / length * width / 2
        poly = [(ax + nx, ay + ny), (bx + nx, by + ny), (bx - nx, by - ny), (ax - nx, ay - ny)]
        x0, y0, x1, y1 = self._boxes([poly], 2)
        cov = coverage([poly], (x0, y0, x1 - x0, y1 - y0))
        c = rgb(color) if isinstance(color, str) else color
        self.over(c, cov * alpha, x0, y0)

    def fill_rect(self, color, x0, y0, x1, y1, fiber=0.05) -> None:
        h, w = y1 - y0, x1 - x0
        c = rgb(color) if isinstance(color, str) else color
        self.over(self.texture(c, x0, y0, h, w, fiber), np.ones((h, w), np.float32), x0, y0)

    def vertical_gradient(self, stops, fiber=0.04) -> None:
        ys = np.linspace(0, 1, self.h)
        cols = np.zeros((self.h, 3))
        positions = [p for p, _ in stops]
        for ch in range(3):
            cols[:, ch] = np.interp(ys, positions, [rgb(c)[ch] for _, c in stops])
        img = np.broadcast_to(cols[:, None, :], (self.h, self.w, 3)).astype(np.float32).copy()
        if self.fiber is not None:
            fy = np.arange(self.h) % self.fiber.shape[0]
            fx = np.arange(self.w) % self.fiber.shape[1]
            img *= (1.0 + fiber * self.fiber[np.ix_(fy, fx)])[..., None]
        self.over(img, np.ones((self.h, self.w), np.float32), 0, 0)

    # --- výstup -------------------------------------------------------------
    def image(self) -> Image.Image:
        a = np.clip(self.a, 0, 1)
        col = np.where(a[..., None] > 1e-5, self.rgb / np.maximum(a[..., None], 1e-5), 0)
        out = np.dstack([np.clip(col, 0, 1), a])
        return Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGBA")

    def save(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        self.image().save(path, optimize=True)


def fiber_field(w: int, h: int, rng: np.random.Generator, fibers: int = 900,
                scale: float = 1.0) -> np.ndarray:
    """Periodická vláknitá struktura papíru (−1..1): mapování, vlákna, tečky."""
    mott = periodic_noise(w, h, 2.6, rng) * 0.45
    grain = periodic_noise(w, h, 0.6, rng) * 0.25
    img = Image.new("L", (w * 2, h * 2), 128)
    draw = ImageDraw.Draw(img)
    for _ in range(fibers):
        x, y = rng.uniform(0, w * 2), rng.uniform(0, h * 2)
        ang = rng.uniform(0, math.tau)
        length = rng.uniform(6, 26) * scale * 2
        bend = rng.uniform(-0.6, 0.6)
        shade = int(rng.choice([96, 104, 150, 160, 168]))
        pts = []
        for i in range(6):
            t = i / 5
            a = ang + bend * (t - 0.5)
            pts.append((x + math.cos(a) * length * t, y + math.sin(a) * length * t))
        for ox in (-w * 2, 0, w * 2):
            for oy in (-h * 2, 0, h * 2):
                draw.line([(px + ox, py + oy) for px, py in pts], fill=shade, width=1)
    fib = np.asarray(img.resize((w, h), Image.BILINEAR), np.float32)
    fib = (fib - 128.0) / 40.0
    speck = np.zeros((h, w), np.float32)
    count = int(w * h / 900)
    sx = rng.integers(0, w, count)
    sy = rng.integers(0, h, count)
    speck[sy, sx] = rng.choice([-1.0, 1.0], count) * rng.uniform(0.6, 1.4, count)
    speck = ndimage.gaussian_filter(speck, 0.7, mode="wrap") * 3.0
    out = mott + grain + fib * 0.55 + speck
    return np.clip(out / 1.2, -1, 1).astype(np.float32)


def save_gray(field: np.ndarray, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(np.clip(field * 0.5 + 0.5, 0, 1).__mul__(255).astype(np.uint8), "L").save(
        path, optimize=True)


def regular_star(cx, cy, r, points, inner, rot=0.0):
    out = []
    for i in range(points * 2):
        rr = r if i % 2 == 0 else r * inner
        a = rot + i * math.pi / points
        out.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    return out


def ellipse(cx, cy, rx, ry, n=48, rot=0.0):
    out = []
    for i in range(n):
        a = i * math.tau / n
        x, y = math.cos(a) * rx, math.sin(a) * ry
        out.append((cx + x * math.cos(rot) - y * math.sin(rot), cy + x * math.sin(rot) + y * math.cos(rot)))
    return out


def transform(points, dx=0.0, dy=0.0, sx=1.0, sy=1.0, rot=0.0, ox=0.0, oy=0.0):
    out = []
    c, s = math.cos(rot), math.sin(rot)
    for x, y in points:
        x, y = (x - ox) * sx, (y - oy) * sy
        out.append((x * c - y * s + ox + dx, x * s + y * c + oy + dy))
    return out
