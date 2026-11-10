"""Iteration 1.7: textures for the combat effects, generated procedurally.

python tools/fx/make_fx_textures.py [out_dir]   (default assets/fx/textures)

White RGB with the shape in alpha, so materials tint them and additive blending
uses alpha as intensity. The summoning circle follows the designer's reference for
Ignar (concentric rings, diamond markers and a central flame emblem); it is drawn
here from simple shapes, not traced from that image. Requires numpy, scipy, Pillow.
"""
import math
import pathlib
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy.spatial import cKDTree

rng = np.random.default_rng(1707)


def grid(size):
    v, u = np.mgrid[0:size, 0:size]
    u = (u + 0.5) / size * 2 - 1
    v = 1 - (v + 0.5) / size * 2
    return u, v


def save(out, name, alpha, rgb=None):
    alpha = np.clip(alpha, 0, 1)
    h, w = alpha.shape
    data = np.zeros((h, w, 4), np.uint8)
    if rgb is None:
        data[..., :3] = 255
    else:
        data[..., :3] = np.clip(rgb * 255, 0, 255).astype(np.uint8)
    data[..., 3] = (alpha * 255).astype(np.uint8)
    Image.fromarray(data).save(out / f"{name}.png", optimize=True)


def soft_dot(size=64):
    u, v = grid(size)
    r = np.sqrt(u * u + v * v)
    return np.clip(1 - r, 0, 1) ** 2


def spark_star(size=128):
    u, v = grid(size)
    au, av = np.abs(u), np.abs(v)
    cross = np.exp(-au * 30) * np.clip(1 - av, 0, 1) ** 3 + np.exp(-av * 30) * np.clip(1 - au, 0, 1) ** 3
    diag_u, diag_v = np.abs(u + v) / math.sqrt(2), np.abs(u - v) / math.sqrt(2)
    diag = (np.exp(-diag_u * 45) * np.clip(1 - diag_v * 1.6, 0, 1) ** 3 + np.exp(-diag_v * 45) * np.clip(1 - diag_u * 1.6, 0, 1) ** 3) * 0.45
    core = np.exp(-(u * u + v * v) * 28)
    edge = np.clip(1 - np.sqrt(u * u + v * v), 0, 1) ** 0.5
    return np.clip(cross + diag + core, 0, 1) * edge


def slash(size=256):
    """Crescent sweep, thick in the middle, tapering to sharp tips."""
    u, v = grid(size)
    cx, cy, radius = -0.95, -0.95, 1.62
    dx, dy = u - cx, v - cy
    dist = np.sqrt(dx * dx + dy * dy) - radius
    theta = np.arctan2(dy, dx)
    a0, a1 = math.radians(6), math.radians(84)
    s = np.clip((theta - a0) / (a1 - a0), 0, 1)
    width = 0.17 * np.sin(np.pi * s) ** 0.9 + 1e-4
    inside = (theta > a0) & (theta < a1)
    # Sharp outer edge, soft trailing inner edge.
    body = np.where(dist > 0, np.exp(-(dist / (width * 0.35)) ** 2), np.exp(-(dist / width) ** 2 * 1.4))
    hot = np.exp(-((dist - width * 0.05) / (width * 0.25)) ** 2) * 0.6
    return np.clip((body + hot) * inside * np.sin(np.pi * s) ** 0.6, 0, 1)


def ring(size=128, inner=0.80, outer=0.95):
    u, v = grid(size)
    r = np.sqrt(u * u + v * v)
    mid, half = (inner + outer) / 2, (outer - inner) / 2
    band = np.exp(-((r - mid) / half) ** 2 * 2.2)
    fill = np.clip(1 - r / outer, 0, 1) * 0.12
    return np.clip(band + fill, 0, 1) * (r < 1)


def flame(size=128):
    """Teardrop blob: round base, tapering tip (up)."""
    u, v = grid(size)
    y = (v + 1) / 2
    half_width = 0.55 * np.sqrt(np.clip(np.sin(np.pi * np.clip(y * 1.15, 0, 1)), 0, 1)) * (1 - y) ** 0.35
    d = np.abs(u) / (half_width + 1e-4)
    return np.clip(1 - d, 0, 1) ** 1.2 * np.clip(y * 6, 0, 1)


def chevron(size=128):
    img = Image.new("L", (size * 4, size * 4), 0)
    d = ImageDraw.Draw(img)
    s = size * 4
    pts = [(0.12, 0.72), (0.5, 0.28), (0.88, 0.72), (0.74, 0.82), (0.5, 0.54), (0.26, 0.82)]
    d.polygon([(x * s, y * s) for x, y in pts], fill=255)
    img = img.resize((size, size), Image.LANCZOS)
    glow = img.filter(ImageFilter.GaussianBlur(size * 0.05))
    a = np.asarray(img, float) / 255
    return np.clip(a + np.asarray(glow, float) / 255 * 0.5, 0, 1)


def gradient_column(height=128):
    v = np.linspace(0, 1, height)[:, None] * np.ones((1, 8))
    # Row 0 is the top of the texture: fade out upwards, soft fade at the base.
    up = 1 - v
    return np.clip(v ** 1.3 * np.clip(up * 12, 0, 1), 0, 1)


def lava_cracks(size=512, points=70):
    """Branching ground cracks from a Voronoi edge network, fading outwards."""
    u, v = grid(size)
    r = np.sqrt(u * u + v * v)
    seeds = rng.uniform(-1.1, 1.1, (points, 2))
    tree = cKDTree(seeds)
    dists, _ = tree.query(np.stack([u.ravel(), v.ravel()], 1), k=2)
    edge = (dists[:, 1] - dists[:, 0]).reshape(size, size)
    warp = np.asarray(Image.fromarray((rng.random((32, 32)) * 255).astype(np.uint8)).resize((size, size), Image.BICUBIC), float) / 255
    line = np.exp(-(edge / (0.010 + 0.012 * warp)) ** 2)
    return np.clip(line * np.clip(1.05 - r, 0, 1) ** 0.8 * 1.3, 0, 1)


def frost(size=256, arms=9):
    s = size * 4
    img = Image.new("L", (s, s), 0)
    d = ImageDraw.Draw(img)
    c = s / 2
    for i in range(arms):
        a = i / arms * math.tau + rng.uniform(-0.15, 0.15)
        length = rng.uniform(0.62, 0.95) * c
        x1, y1 = c + math.cos(a) * length, c + math.sin(a) * length
        d.line([(c, c), (x1, y1)], fill=255, width=int(s * 0.012))
        for k in range(4):
            t = rng.uniform(0.25, 0.85)
            bx, by = c + math.cos(a) * length * t, c + math.sin(a) * length * t
            for side in (-1, 1):
                b = a + side * rng.uniform(0.45, 0.8)
                bl = length * rng.uniform(0.12, 0.28)
                d.line([(bx, by), (bx + math.cos(b) * bl, by + math.sin(b) * bl)], fill=200, width=int(s * 0.007))
    img = img.resize((size, size), Image.LANCZOS)
    glow = np.asarray(img.filter(ImageFilter.GaussianBlur(size * 0.02)), float) / 255
    a = np.asarray(img, float) / 255
    u, v = grid(size)
    return np.clip((a + glow * 0.8) * np.clip(1.05 - np.sqrt(u * u + v * v), 0, 1), 0, 1)


def flame_emblem(d, cx, cy, scale):
    """Three-tongued flame over a cup: the central emblem of the designer's circle."""
    def tongue(x0, height, width, lean):
        pts = []
        for i in range(41):
            t = i / 40
            y = cy - t * height
            w = width * math.sin(math.pi * min(1, t * 1.05)) ** 0.8 * (1 - t) ** 0.5
            x = x0 + lean * t * t * height
            pts.append((x - w, y))
        for i in range(40, -1, -1):
            t = i / 40
            y = cy - t * height
            w = width * math.sin(math.pi * min(1, t * 1.05)) ** 0.8 * (1 - t) ** 0.5
            x = x0 + lean * t * t * height
            pts.append((x + w, y))
        d.polygon(pts, fill=255)
    tongue(cx, scale * 0.95, scale * 0.17, 0.0)
    tongue(cx - scale * 0.24, scale * 0.62, scale * 0.12, -0.32)
    tongue(cx + scale * 0.24, scale * 0.62, scale * 0.12, 0.32)
    # Cup (crescent) beneath the flame.
    box = [cx - scale * 0.46, cy - scale * 0.55, cx + scale * 0.46, cy + scale * 0.3]
    d.arc(box, 20, 160, fill=255, width=int(scale * 0.07))


def rune_circle(size=512):
    s = size * 4
    img = Image.new("L", (s, s), 0)
    d = ImageDraw.Draw(img)
    c = s / 2

    def circle(radius, width):
        r = radius * c
        d.ellipse([c - r, c - r, c + r, c + r], outline=255, width=max(1, int(width * c)))

    def diamond(angle, radius, length, width):
        x, y = c + math.cos(angle) * radius * c, c - math.sin(angle) * radius * c
        ax, ay = math.cos(angle), -math.sin(angle)
        px, py = -ay, ax
        pts = [(x + ax * length * c, y + ay * length * c), (x + px * width * c, y + py * width * c),
               (x - ax * length * c, y - ay * length * c), (x - px * width * c, y - py * width * c)]
        d.polygon(pts, fill=255)

    circle(0.97, 0.014)
    circle(0.90, 0.008)
    circle(0.62, 0.012)
    circle(0.56, 0.006)
    for i in range(8):
        a = i * math.pi / 4 + math.pi / 8
        diamond(a, 0.935, 0.035, 0.018)
        # Spokes between the inner and outer bands.
        x0, y0 = c + math.cos(a) * 0.62 * c, c - math.sin(a) * 0.62 * c
        x1, y1 = c + math.cos(a) * 0.90 * c, c - math.sin(a) * 0.90 * c
        d.line([(x0, y0), (x1, y1)], fill=170, width=int(0.006 * c))
    for i in range(4):
        a = i * math.pi / 2 + math.pi / 2
        diamond(a, 0.76, 0.11, 0.045)
        diamond(a, 1.0, 0.05, 0.03)
        # Hollow lozenge inside each large diamond.
        x, y = c + math.cos(a) * 0.76 * c, c - math.sin(a) * 0.76 * c
        d.ellipse([x - 0.018 * c, y - 0.018 * c, x + 0.018 * c, y + 0.018 * c], fill=0)
    # Arc segments on the inner band (crescents between the large diamonds).
    for i in range(4):
        start = i * 90 + 18
        r = 0.70 * c
        d.arc([c - r, c - r, c + r, c + r], start, start + 54, fill=220, width=int(0.010 * c))
    flame_emblem(d, c, c + 0.22 * c, 0.56 * c)
    img = img.resize((size, size), Image.LANCZOS)
    lines = np.asarray(img, float) / 255
    glow = np.asarray(img.filter(ImageFilter.GaussianBlur(size * 0.012)), float) / 255
    return np.clip(lines + glow * 0.9, 0, 1)


def main():
    out = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "assets/fx/textures")
    out.mkdir(parents=True, exist_ok=True)
    save(out, "soft_dot", soft_dot())
    save(out, "spark_star", spark_star())
    save(out, "slash", slash())
    save(out, "ring", ring())
    save(out, "ring_thin", ring(128, 0.88, 0.96))
    save(out, "flame", flame())
    save(out, "chevron", chevron())
    save(out, "column", gradient_column())
    save(out, "lava_cracks", lava_cracks())
    save(out, "frost", frost())
    save(out, "rune_circle", rune_circle())
    for f in sorted(out.glob("*.png")):
        print(f.name, f.stat().st_size)


if __name__ == "__main__":
    main()
