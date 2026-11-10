"""Ground mask for the HD Eclipse Forest (python tools/forest_hd_mask.py).

R = trail (same polylines as tools/blender/build_eclipse_clearing.py PATHS)
G = meadow (open, walkable clearing away from trails)
B = plaza under the ruins (pavement)
Covers MASK_X x MASK_Z in world metres (Godot X / Z). Writes an 8-bit RGB PNG.
"""
import math, struct, zlib
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/environments/eclipse_forest_hd/ground_mask.png'
MASK_X, MASK_Z, SIZE = (-32.0, 32.0), (-34.0, 21.0), 1024
PATHS = [
    ([(-5.2, 13), (-5.1, 8), (-5, 5.2), (-4.7, 3.4), (-3.6, 1.8), (-2, 1.2), (0, 1), (2.4, .6), (4.6, .9), (7, 1.4), (9.5, 1.2), (13, .4), (18, -.6)], .95),
    ([(-.9, 1.0), (-.6, -.4), (-.3, -1.6), (0, -2.9), (0, -4.1)], .78),
    ([(2.4, .6), (3.4, -1.2), (4.6, -2.4), (5.6, -3.6), (6.3, -5.2), (6.9, -8), (7.8, -11)], .62),
    ([(-.6, -.4), (-1.7, -1.5), (-2.4, -2.2)], .42),
]
PLAZA = ((0, -3.4), 2.15)
PLAY_X, PLAY_Z = 8.45, 6.45


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def value_noise(shape, cells, seed):
    rng = np.random.default_rng(seed)
    grid = rng.random((cells + 1, cells + 1))
    ys, xs = np.linspace(0, cells, shape[0], endpoint=False), np.linspace(0, cells, shape[1], endpoint=False)
    yi, xi = ys.astype(int), xs.astype(int)
    fy, fx = smooth(0, 1, ys - yi)[:, None], smooth(0, 1, xs - xi)[None, :]
    a, b = grid[yi][:, xi], grid[yi][:, xi + 1]
    c, d = grid[yi + 1][:, xi], grid[yi + 1][:, xi + 1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(shape, base, seed, octaves=4):
    out, amp, tot = np.zeros(shape), 1.0, 0.0
    for i in range(octaves):
        out += amp * value_noise(shape, base * 2 ** i, seed + i)
        tot += amp
        amp *= .5
    return out / tot


h = w = SIZE
x = np.linspace(MASK_X[0], MASK_X[1], w)[None, :].repeat(h, 0)
z = np.linspace(MASK_Z[0], MASK_Z[1], h)[:, None].repeat(w, 1)
noise = fbm((h, w), 12, 7)
fine = fbm((h, w), 70, 11, 3)
path = np.zeros((h, w))
for pts, width in PATHS:
    d = np.full((h, w), 1e9)
    for (ax, az), (bx, bz) in zip(pts, pts[1:]):
        dx, dz = bx - ax, bz - az
        t = np.clip(((x - ax) * dx + (z - az) * dz) / (dx * dx + dz * dz), 0, 1)
        d = np.minimum(d, np.hypot(x - ax - t * dx, z - az - t * dz))
    edge = width * (.78 + .45 * (noise - .5)) + .18 * (fine - .5)
    path = np.maximum(path, 1 - smooth(edge * .55, edge, d))
(px, pz), pr = PLAZA
plaza = 1 - smooth(pr * .8, pr * 1.08 + .25 * (noise - .5), np.hypot(x - px, z - pz))
inside = (1 - smooth(PLAY_X - .6, PLAY_X + 1.6, np.abs(x))) * (1 - smooth(PLAY_Z - .4, PLAY_Z + 1.4, np.abs(z)))
meadow = np.clip(inside * (1 - path) * (1 - plaza) * smooth(.35, .6, noise + .25 * fine), 0, 1)
rgb = (np.stack([path, meadow, plaza], -1) * 255 + .5).astype(np.uint8)


def write_png(path_, img):
    raw = b''.join(b'\x00' + img[i].tobytes() for i in range(img.shape[0]))
    def chunk(t, d):
        return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    path_.parent.mkdir(parents=True, exist_ok=True)
    path_.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', img.shape[1], img.shape[0], 8, 2, 0, 0, 0))
                      + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))


write_png(OUT, rgb)
print('mask', OUT, rgb.shape)
