"""Eclipse forest clearing 1.1: original stylized kit, terrain paint and layout.

Run in a separate background Blender process:
  blender --background --factory-startup --python-exit-code 1 --python tools/blender/build_eclipse_clearing.py
  ... -- --export-only   reopen the saved .blend (keeps manual edits) and re-export.

Every mesh, colour and texture is authored here; no third-party assets.
Authoring helpers use Godot coordinates (X right, Y up, Z towards the camera)
and convert to Blender Z-up. Gameplay colliders live in Godot and are NOT
generated here: tree trunks, rocks and columns are only dressed around them.
"""
import bpy
import bmesh
import math
import random
import json
import hashlib
import struct
import sys
from pathlib import Path
from mathutils import Vector, noise
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/environments/eclipse_forest'
OUT.mkdir(parents=True, exist_ok=True)
BLEND = OUT / 'eclipse_clearing.blend'
GLB = OUT / 'eclipse_clearing.glb'
TAU = math.tau

# ---------------------------------------------------------------- gameplay map
# Copied from forest_zone.gd / expedition_story.gd. Only used to compose art.
TREE_COLLIDERS = [(-7, -4.5), (-7.4, 0), (-7.3, 4.8), (-3.5, -4.7), (0, -5), (3.4, -5.2), (7.1, -4.6), (7.2, 0), (7.2, 4.7)]
ROCK_COLLIDERS = [((-1.3, 4.8), (1.2, .9, .9)), ((4.3, 3.3), (1.0, 1.1, 1.2))]
COLUMNS = [(-2.7, -1.5), (2.1, -1.5)]
KEEP_CLEAR = [  # gameplay anchors: no props that could hide or clip them
    ((-5, 4), 1.1), ((-4.5, 2), 1.5), ((3.1, -.5), 1.3), ((-2.4, -2.2), 1.0), ((0, -2.9), 1.5),
    ((0, 1), 1.4), ((5, -2.8), 1.4)]
PLAY_X, PLAY_Z = 8.45, 6.45   # inner faces of the boundary walls
# Painted trails. They follow the real exploration route.
PATHS = [
    ([(-5.2, 13), (-5.1, 8), (-5, 5.2), (-4.7, 3.4), (-3.6, 1.8), (-2, 1.2), (0, 1), (2.4, .6), (4.6, .9), (7, 1.4), (9.5, 1.2), (13, .4), (18, -.6)], .95),
    ([(-.9, 1.0), (-.6, -.4), (-.3, -1.6), (0, -2.9), (0, -4.1)], .78),
    ([(2.4, .6), (3.4, -1.2), (4.6, -2.4), (5.6, -3.6), (6.3, -5.2), (6.9, -8), (7.8, -11)], .62),
    ([(-.6, -.4), (-1.7, -1.5), (-2.4, -2.2)], .42),
]
PLAZA = ((0, -3.4), 2.15)
TERRAIN_X, TERRAIN_Z = (-32.0, 32.0), (-34.0, 21.0)
PAINT_X, PAINT_Z = (-24.0, 24.0), (-28.0, 12.0)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def hexrgb(value):
    return tuple(int(value[i:i + 2], 16) / 255 for i in (0, 2, 4))


def lin(c):
    return tuple(v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in c)


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def mul(a, k):
    return tuple(max(0.0, min(1.0, x * k)) for x in a)


def smooth(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def to_blender(p):
    return (p[0], -p[2], p[1])


def n3(x, y, z):
    return noise.noise(Vector((x, y, z)))


# ----------------------------------------------------------------- materials
MATERIALS = {}


def material(name, preview):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    tree = mat.node_tree
    bsdf = next(n for n in tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Roughness'].default_value = .95
    attr = tree.nodes.new('ShaderNodeVertexColor')
    attr.layer_name = 'Color'
    tree.links.new(attr.outputs['Color'], bsdf.inputs['Base Color'])
    mat.diffuse_color = lin(hexrgb(preview)) + (1,)
    MATERIALS[name] = mat
    return mat


def make_materials():
    # Names are the contract with world/forest_art.gd, which swaps in mobile shaders.
    for name, preview in [('Bark', '7a4b33'), ('Foliage', '5f8f34'), ('Plant', '78a53c'), ('Stone', '948e74'), ('Ground', '6c8f3a'), ('Bloom', 'e0c75a')]:
        material(name, preview)


# ------------------------------------------------------------------ builder
class Builder:
    def __init__(self):
        self.v, self.c, self.f, self.m = [], [], [], []

    def vert(self, p, rgb):
        self.v.append(tuple(p))
        self.c.append(tuple(rgb))
        return len(self.v) - 1

    def face(self, ids, mat=0):
        self.f.append(tuple(ids))
        self.m.append(mat)

    def mesh(self, name, mats, recalc=True):
        data = bpy.data.meshes.new(name)
        data.from_pydata([to_blender(p) for p in self.v], [], self.f)
        data.update()
        attr = data.color_attributes.new(name='Color', type='BYTE_COLOR', domain='POINT')
        for item, rgb in zip(attr.data, self.c):
            item.color_srgb = tuple(max(0, min(1, x)) for x in rgb) + (1,)
        data.color_attributes.active_color = attr
        data.color_attributes.render_color_index = 0
        for mat in mats:
            data.materials.append(MATERIALS[mat])
        for poly, slot in zip(data.polygons, self.m):
            poly.material_index = slot
            poly.use_smooth = True
        if recalc:
            bm = bmesh.new()
            bm.from_mesh(data)
            closed = [f for f in bm.faces if data.polygons[f.index].material_index in self.closed_slots]
            if closed:
                bmesh.ops.recalc_face_normals(bm, faces=closed)
            bm.to_mesh(data)
            bm.free()
        return data

    closed_slots = (0,)


ICO = {}


def ico(subdiv):
    if subdiv not in ICO:
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1)
        ICO[subdiv] = ([Vector(v.co).normalized() for v in bm.verts], [[v.index for v in f.verts] for f in bm.faces])
        bm.free()
    return ICO[subdiv]


def blob_radius(u, seed, rough=1.0):
    o = Vector((seed * 3.17, seed * 1.73, seed * 2.31))
    return 1 + rough * (.17 * noise.noise(u * 1.6 + o) + .07 * noise.noise(u * 4.2 + o * 1.3))


def blob(b, center, radii, seed, color, subdiv=2, mat=0, rough=1.0, flat=-.45):
    verts, faces = ico(subdiv)
    center = Vector(center)
    base = len(b.v)
    for u in verts:
        r = blob_radius(u, seed, rough)
        y = u.y
        if y < flat:
            y = flat + (y - flat) * .35
        p = center + Vector((u.x * radii[0] * r, y * radii[1] * r, u.z * radii[2] * r))
        b.vert(p, color(p, u))
    for f in faces:
        b.face([base + i for i in f], mat)


def frames(points):
    tangents = []
    for j in range(len(points)):
        t = points[min(j + 1, len(points) - 1)] - points[max(j - 1, 0)]
        tangents.append(t.normalized())
    ref = Vector((0, 0, 1)) if abs(tangents[0].z) < .9 else Vector((1, 0, 0))
    normal = (ref - tangents[0] * ref.dot(tangents[0])).normalized()
    out = []
    for t in tangents:
        normal = (normal - t * normal.dot(t)).normalized()
        out.append((t, normal, t.cross(normal)))
    return out


def tube(b, points, radii, color, sides=9, mat=0, seed=0, flute=.12, cap=True):
    points = [Vector(p) for p in points]
    rings = []
    for j, (p, r, (t, nrm, bin_)) in enumerate(zip(points, radii, frames(points))):
        ring = []
        for i in range(sides):
            a = i * TAU / sides
            k = 1 + flute * math.sin(a * 4 + seed) + flute * .5 * n3(math.cos(a) * 1.3 + seed, j * .4, math.sin(a) * 1.3)
            q = p + (nrm * math.cos(a) + bin_ * math.sin(a)) * r * k
            ring.append(b.vert(q, color(q, a, j / max(1, len(points) - 1))))
        rings.append(ring)
    for lo, hi in zip(rings, rings[1:]):
        for i in range(sides):
            b.face([lo[i], lo[(i + 1) % sides], hi[(i + 1) % sides], hi[i]], mat)
    if cap:
        tip = b.vert(points[-1] + frames(points)[-1][0] * radii[-1] * .4, color(points[-1], 0, 1))
        top = rings[-1]
        for i in range(sides):
            b.face([top[i], top[(i + 1) % sides], tip], mat)


def bezier(p0, p1, p2, steps):
    p0, p1, p2 = Vector(p0), Vector(p1), Vector(p2)
    return [(1 - t) ** 2 * p0 + 2 * (1 - t) * t * p1 + t * t * p2 for t in [i / steps for i in range(steps + 1)]]


def leaf(b, p, n, t, size, rgb, mat):
    """Opaque shingle leaf: a creased diamond whose midrib catches light."""
    side = n.cross(t).normalized()
    mid = p + t * size * .4 - n * size * .1   # wings fold back: midrib catches light
    i0 = b.vert(p - t * size * .1, mul(rgb, .72))
    i1 = b.vert(p + t * size, mul(rgb, 1.18))
    left = b.vert(mid + side * size * .34, mul(rgb, .95))
    right = b.vert(mid - side * size * .34, mul(rgb, .95))
    b.face([i0, right, i1], mat)
    b.face([i0, i1, left], mat)


def leaf_shell(b, center, radii, seed, size, palette, density=1.0, mat=1, lower=-.2):
    rng = random.Random(seed)
    dark, mid, light, accent = palette
    area = 4 * math.pi * ((radii[0] * radii[1] + radii[1] * radii[2] + radii[0] * radii[2]) / 3)
    count = int(min(900, density * 1.25 * area / (size * size * .34)))
    center = Vector(center)
    golden = math.pi * (3 - math.sqrt(5))
    for i in range(count):
        y = 1 - 2 * (i + .5) / count
        if y < lower:
            continue
        rad = math.sqrt(max(0, 1 - y * y))
        a = i * golden + rng.uniform(-.25, .25)
        u = Vector((math.cos(a) * rad, y, math.sin(a) * rad)).normalized()
        r = blob_radius(u, seed) * 1.03
        p = center + Vector((u.x * radii[0] * r, u.y * radii[1] * r, u.z * radii[2] * r))
        n = Vector((u.x / radii[0], u.y / radii[1], u.z / radii[2])).normalized()
        down = Vector((0, -1, 0))
        t = down - n * down.dot(n)
        if t.length < .25:
            t = Vector((math.cos(a + 1.7), 0, math.sin(a + 1.7)))
            t = t - n * t.dot(n)
        t = (t.normalized() + n * rng.uniform(.25, .55)).normalized()
        light_amount = .5 + .42 * u.y + .12 * n3(p.x * .8, p.y * .8, p.z * .8 + seed)
        rgb = mix(dark, mid, light_amount * 1.6) if light_amount < .62 else mix(mid, light, (light_amount - .62) * 2.0)
        if rng.random() < .045:
            rgb = mix(rgb, accent, .5)
        rgb = mul(rgb, rng.uniform(.92, 1.08))
        leaf(b, p, n, t, size * rng.uniform(.8, 1.2), rgb, mat)


# ---------------------------------------------------------------- palettes
H = hexrgb
LEAF_SPRING = (H('2c5428'), H('518530'), H('8cb045'), H('c4bd5c'))
LEAF_DEEP = (H('1e3828'), H('36613a'), H('689442'), H('93a656'))
LEAF_WARM = (H('32502a'), H('62852f'), H('a3ad4b'), H('c88c40'))
LEAF_ANCIENT = (H('26452b'), H('467634'), H('85a849'), H('c4924f'))
BARK = (H('3e2a1f'), H('6e4a34'), H('93684a'))
BARK_GREY = (H('4b3f33'), H('786652'), H('9c8a70'))


def bark_color(palette, seed):
    dark, mid, light = palette

    def color(p, a, t):
        streak = .5 + .5 * math.sin(a * 6 + seed + 2 * n3(p.x * 2, p.y * .7, p.z * 2))
        rgb = mix(mid, light, streak * .55)
        rgb = mix(dark, rgb, .35 + .65 * smooth(0, .8, p.y))
        if p.y < .25:  # moss on the root flare
            rgb = mix(rgb, H('4f6e2c'), .45 * (1 - p.y / .25))
        return rgb
    return color


def crown_dark(palette):
    dark, mid = palette[0], palette[1]

    def color(p, u):
        return mix(dark, mid, .35 + .45 * max(0, u.y))
    return color


# ------------------------------------------------------------------- trees
def roots(b, count, radius, reach, seed, color, sides=7):
    rng = random.Random(seed)
    start = rng.uniform(0, TAU)
    for i in range(count):
        a = start + i * TAU / count + rng.uniform(-.45, .45)
        d = Vector((math.cos(a), 0, math.sin(a)))
        r = reach * rng.uniform(.45, 1.0)
        pts = bezier(d * radius * .4 + Vector((0, radius * 1.3, 0)), d * (radius + r * .3) + Vector((0, radius * .45, 0)), d * (radius + r) + Vector((0, -.2, 0)), 5)
        tube(b, pts, [radius * .62 * (1 - k / 7) + .05 for k in range(6)], color, sides=sides, seed=seed + i, flute=.08, cap=False)


def tree_broad(seed, height, trunk, crown, palette, lean=(0, 0), bark=BARK, leaf_size=.3, clumps=7, density=.85, full=True, leaves=True):
    rng = random.Random(seed)
    b = Builder()
    color = bark_color(bark, seed)
    lean = Vector((lean[0], 0, lean[1]))
    trunk_pts = [Vector((0, 0, 0)), Vector((0, height * .25, 0)) + lean * .15, Vector((0, height * .55, 0)) + lean * .45, Vector((0, height * .82, 0)) + lean * .8, Vector((0, height, 0)) + lean]
    tube(b, trunk_pts, [trunk * 1.25, trunk, trunk * .82, trunk * .68, trunk * .5], color, sides=11, seed=seed, flute=.14)
    if full:
        roots(b, 4, trunk, trunk * 1.8, seed, color)
    top = trunk_pts[-1]
    centers = [(top + Vector((0, crown * .55, 0)), (crown, crown * .78, crown))]
    for i in range(clumps - 1):
        a = i * TAU / (clumps - 1) + rng.uniform(-.35, .35)
        dist = crown * rng.uniform(.72, .95)
        size = crown * rng.uniform(.52, .72)
        h = rng.uniform(-.45, .35) * crown
        c = top + Vector((math.cos(a) * dist, crown * .35 + h, math.sin(a) * dist))
        centers.append((c, (size, size * .8, size)))
        # Visible branch reaching into each lower clump.
        if full and h < .1 * crown:
            start = trunk_pts[3] + (top - trunk_pts[3]) * rng.uniform(.1, .6)
            tube(b, bezier(start, (start + c) * .5 + Vector((0, .25, 0)), c - (c - start).normalized() * size * .4, 3), [trunk * .42, trunk * .32, trunk * .24, trunk * .16], color, sides=6, seed=seed + 9 + i, flute=.05)
    for k, (c, r) in enumerate(centers):
        blob(b, c, r, seed + k * 7, crown_dark(palette), subdiv=2, mat=1)
        if leaves:
            leaf_shell(b, c, r, seed + k * 7, leaf_size * (crown / 1.6) ** .4, palette, density, mat=1)
    b.closed_slots = (0,)
    return b


def tree_pine(seed, height, radius, tiers, palette=(H('1f3d2c'), H('2f5f37'), H('5c8f3f'), H('8fb555')), full=True, points=11):
    rng = random.Random(seed)
    b = Builder()
    color = bark_color(BARK_GREY if not full else BARK, seed)
    tube(b, [Vector((0, 0, 0)), Vector((0, height * .5, 0)), Vector((0, height * .92, 0))], [.32, .22, .08], color, sides=8, seed=seed)
    if full:
        roots(b, 4, .3, .55, seed, color, sides=5)
    dark, mid, light, tip = palette
    for k in range(tiers):
        f = k / max(1, tiers - 1)
        y0 = height * (.28 + .64 * f)
        r = radius * (1 - .78 * f) * rng.uniform(.93, 1.07)
        thick = height * .2 * (1 - .4 * f)
        apex = b.vert((0, y0 + thick, 0), mul(mid, .9))
        under = b.vert((0, y0 + thick * .15, 0), mul(dark, .7))
        mids, rims, lows = [], [], []
        for i in range(points * 2):
            a = i * TAU / (points * 2) + k * .37
            rr = r * (1 if i % 2 == 0 else .74) * rng.uniform(.92, 1.08)
            droop = -thick * (.45 if i % 2 == 0 else .25)
            mids.append(b.vert((math.cos(a) * rr * .55, y0 + thick * .62, math.sin(a) * rr * .55), mix(mid, light, .35)))
            rims.append(b.vert((math.cos(a) * rr, y0 + droop, math.sin(a) * rr), mix(light, tip, .5) if i % 2 == 0 else mix(mid, light, .6)))
            lows.append(b.vert((math.cos(a) * rr * .6, y0 - thick * .05, math.sin(a) * rr * .6), mul(dark, .85)))
        n = points * 2
        for i in range(n):
            j = (i + 1) % n
            b.face([apex, mids[j], mids[i]], 1)
            b.face([mids[i], mids[j], rims[j], rims[i]], 1)
            b.face([rims[i], rims[j], lows[j], lows[i]], 1)
            b.face([lows[i], lows[j], under], 1)
    b.closed_slots = (0, 1)
    return b


def tree_ancient():
    """Focal tree over the ruins: wide fluted trunk splitting into three limbs,
    buttress roots that are low at the front (walkable plaza) and arch at the back."""
    b = Builder()
    color = bark_color(BARK, 77)
    rng = random.Random(77)
    trunk = [Vector((0, -.1, 0)), Vector((0, .8, .02)), Vector((.05, 1.8, 0)), Vector((.1, 2.7, -.08)), Vector((.12, 3.3, -.12))]
    tube(b, trunk, [.92, .7, .6, .56, .52], color, sides=14, seed=77, flute=.16)
    # Buttresses: wide fins that blend trunk into the ground.
    for i, a in enumerate([.45, 1.9, 2.9, 3.9, 5.3]):
        d = Vector((math.sin(a), 0, math.cos(a)))
        front = math.cos(a) > .5
        reach = rng.uniform(.7, .95) if front else rng.uniform(1.1, 1.7)
        lift = .02 if front else rng.uniform(.1, .25)
        pts = bezier(d * .35 + Vector((0, 1.15, 0)), d * (.75 + reach * .35) + Vector((0, .3 + lift, 0)), d * (.7 + reach) + Vector((0, -.3, 0)) + d.cross(Vector((0, 1, 0))) * rng.uniform(-.4, .4), 8)
        radii = [.44 * (1 - k / 10) ** 1.2 + .07 for k in range(9)]
        tube(b, pts, radii, color, sides=8, seed=80 + i, flute=.1, cap=False)
    # Three main limbs curving out from the crotch, then smaller forks.
    limbs = [((-.9, 1.6, .25), (-2.0, 2.4, .2)), ((1.0, 1.7, -.2), (2.1, 2.2, -.6)), ((.1, 1.9, -.9), (.3, 2.9, -1.6))]
    crotch = trunk[-1]
    for i, (m, e) in enumerate(limbs):
        mid = crotch + Vector(m)
        end = crotch + Vector(e)
        tube(b, bezier(crotch - Vector((0, .3, 0)), mid, end, 6), [.42, .36, .3, .25, .2, .15, .1], color, sides=8, seed=90 + i, flute=.08)
        fork = (mid + end) * .5
        tip = fork + Vector((rng.uniform(-.6, .6), 1.1, rng.uniform(-.6, .6)))
        tube(b, bezier(fork, (fork + tip) * .5 + Vector((0, .2, 0)), tip, 3), [.16, .12, .09, .06], color, sides=6, seed=95 + i, flute=.05)
    clusters = [((.1, 6.4, -.6), (2.2, 1.4, 2.0)), ((-2.3, 5.4, .2), (1.6, 1.15, 1.45)), ((2.4, 5.3, -.5), (1.6, 1.15, 1.45)),
                ((.4, 5.6, -2.4), (1.6, 1.1, 1.4)), ((-1.2, 7.2, -1.3), (1.3, .95, 1.2)), ((1.5, 7.0, -1.4), (1.25, .9, 1.15)), ((.0, 5.3, 1.3), (1.4, .95, 1.2))]
    for k, (c, r) in enumerate(clusters):
        blob(b, c, r, 200 + k, crown_dark(LEAF_ANCIENT), mat=1)
        leaf_shell(b, c, r, 200 + k, .36, LEAF_ANCIENT, 1.0, mat=1)
    return b


# --------------------------------------------------------------- low plants
def bush(seed, size, palette):
    rng = random.Random(seed)
    b = Builder()
    for k in range(4):
        a = k * TAU / 4 + rng.uniform(-.4, .4)
        c = Vector((math.cos(a) * size * .45, size * rng.uniform(.38, .55), math.sin(a) * size * .45)) if k else Vector((0, size * .62, 0))
        r = size * rng.uniform(.45, .62)
        blob(b, c, (r, r * .82, r), seed + k, crown_dark(palette), subdiv=2, mat=0, flat=-.2)
        leaf_shell(b, c, (r, r * .82, r), seed + k, .2 * size ** .5, palette, .9, mat=0, lower=-.05)
    b.closed_slots = ()
    return b


def fern(seed, size):
    rng = random.Random(seed)
    b = Builder()
    dark, light = H('3d6e30'), H('a6cf58')
    fronds = 9
    for k in range(fronds):
        a = k * TAU / fronds + rng.uniform(-.2, .2)
        d = Vector((math.cos(a), 0, math.sin(a)))
        length = size * rng.uniform(.75, 1.05)
        rise = rng.uniform(.55, .85) * length
        spine = bezier(Vector((0, .02, 0)), d * length * .45 + Vector((0, rise, 0)), d * length + Vector((0, rise * .25, 0)), 7)
        side = d.cross(Vector((0, 1, 0))).normalized()
        for j in range(len(spine) - 1):
            p, q = spine[j], spine[j + 1]
            f = j / (len(spine) - 1)
            w = length * .17 * math.sin(math.pi * (.15 + .85 * f)) + .01
            rgb = mix(dark, light, .25 + .75 * f)
            pa = b.vert(p, mul(rgb, .85))
            pb = b.vert(q, rgb)
            for s in (-1, 1):
                tip = b.vert((p + q) * .5 + side * s * w - Vector((0, w * .25, 0)), mul(rgb, 1.08))
                b.face([pa, pb, tip] if s > 0 else [pb, pa, tip], 0)
    b.closed_slots = ()
    return b


def grass(seed, size, palette=(H('35602a'), H('7fae3d'), H('c3d067'))):
    rng = random.Random(seed)
    b = Builder()
    base, mid, tip = palette
    for k in range(9):
        a = rng.uniform(0, TAU)
        r = rng.uniform(0, .12) * size
        root = Vector((math.cos(a) * r, 0, math.sin(a) * r))
        lean = Vector((math.cos(a), 0, math.sin(a))) * rng.uniform(.08, .2) * size
        h = size * rng.uniform(.25, .48)
        w = size * .045
        side = Vector((-math.sin(a + 1.4), 0, math.cos(a + 1.4)))
        p0l, p0r = root - side * w, root + side * w
        p1 = root + lean * .4 + Vector((0, h * .55, 0))
        p2 = root + lean + Vector((0, h, 0))
        i0 = b.vert(p0l, base)
        i1 = b.vert(p0r, base)
        i2 = b.vert(p1 - side * w * .6, mid)
        i3 = b.vert(p1 + side * w * .6, mid)
        i4 = b.vert(p2, tip)
        b.face([i0, i1, i3, i2], 0)
        b.face([i2, i3, i4], 0)
    b.closed_slots = ()
    return b


def flowers(seed, petal, centre=H('f2d057'), count=7, spike=False):
    rng = random.Random(seed)
    b = Builder()
    stem = H('4f7d2d')
    for k in range(count):
        a = rng.uniform(0, TAU)
        r = rng.uniform(.03, .2)
        root = Vector((math.cos(a) * r, 0, math.sin(a) * r))
        h = rng.uniform(.18, .36) * (1.6 if spike else 1)
        top = root + Vector((rng.uniform(-.04, .04), h, rng.uniform(-.04, .04)))
        tube(b, [root, top], [.012, .009], lambda p, a_, t: mix(H('35602a'), stem, t), sides=3, mat=0, cap=False)
        if spike:  # lupin-like spike of small bells
            for j in range(6):
                c = top + Vector((0, j * .045, 0))
                blob(b, c, (.035 - j * .004, .03, .035 - j * .004), seed + k * 7 + j, lambda p, u: mul(petal, .8 + .35 * max(0, u.y)), subdiv=1, mat=1)
            continue
        centre_i = b.vert(top + Vector((0, .012, 0)), centre)
        ring = []
        for i in range(10):
            ang = i * TAU / 10
            rr = .065 if i % 2 == 0 else .03
            ring.append(b.vert(top + Vector((math.cos(ang) * rr, -.005 if i % 2 == 0 else .004, math.sin(ang) * rr)), mul(petal, 1.0 if i % 2 == 0 else .88)))
        for i in range(10):
            b.face([centre_i, ring[(i + 1) % 10], ring[i]], 1)
    for k in range(5):  # a few basal leaves
        a = k * TAU / 5
        d = Vector((math.cos(a), 0, math.sin(a)))
        leaf(b, d * .05 + Vector((0, .03, 0)), Vector((0, 1, 0)), (d + Vector((0, .25, 0))).normalized(), .16, H('5b8f34'), 0)
    b.closed_slots = ()
    return b


def mushrooms(seed):
    rng = random.Random(seed)
    b = Builder()
    for k in range(3):
        a = k * 2.2 + rng.uniform(0, .5)
        base = Vector((math.cos(a) * .12 * k, 0, math.sin(a) * .12 * k))
        h = rng.uniform(.12, .24) * (1.3 if k == 0 else 1)
        tube(b, [base, base + Vector((0, h, 0))], [.035, .028], lambda p, a_, t: H('efe3c8'), sides=6, mat=0, cap=False)
        r = h * .55

        def cap(p, u, o=k):
            spot = n3(u.x * 3 + o, u.y * 3, u.z * 3) > .35
            return H('f4ead2') if spot and u.y > .1 else mix(H('8e2a1d'), H('d0472c'), .4 + .6 * u.y)
        blob(b, base + Vector((0, h, 0)), (r, r * .62, r), seed + k, cap, subdiv=2, mat=0, rough=.25, flat=-.05)
    b.closed_slots = (0,)
    return b


# ------------------------------------------------------------- rocks/ruins
STONE = (H('5c5a4c'), H('83806a'), H('a29d84'))
RUIN = (H('5f5c4d'), H('878169'), H('a59e82'))
PAVE = (H('5e5a4c'), H('7f7965'), H('99927a'))
MOSS = (H('3f6a2a'), H('6f9a38'), H('9cba4c'))


def stone_color(seed, moss=.55, palette=STONE):
    dark, mid, light = palette

    def color(p, u):
        n = n3(p.x * 1.7 + seed, p.y * 1.7, p.z * 1.7)
        fine = n3(p.x * 6.3, p.y * 6.3 + seed, p.z * 6.3)
        rgb = mix(mid, light, .45 + .45 * n + .25 * fine)
        rgb = mix(rgb, mul(dark, .9), .35 * smooth(.25, .7, -fine))
        rgb = mix(mul(dark, .85), rgb, .45 + .55 * smooth(-.6, .4, u.y))
        m = smooth(moss, moss + .25, u.y + .25 * n3(p.x * 2.3, p.y * 2.3 + seed, p.z * 2.3))
        return mix(rgb, mix(MOSS[0], MOSS[2], .3 + .5 * n), m)
    return color


def boulder(seed, size, moss=.45):
    b = Builder()
    blob(b, (0, size[1] * .32, 0), (size[0] * .55, size[1] * .7, size[2] * .55), seed, stone_color(seed, moss + .3), subdiv=3, mat=0, rough=1.5, flat=-.5)
    b.closed_slots = (0,)
    return b


def block(b, center, size, seed, yaw=0.0, moss=.55, chip=.12, palette=STONE):
    """Bevelled, eroded ashlar block. Corner chips and soft edges, mossy top."""
    rng = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    bmesh.ops.bevel(bm, geom=list(bm.edges), offset=min(size) * .18, segments=2, affect='EDGES', profile=.6)
    color = stone_color(seed, moss, palette)
    base = len(b.v)
    cy, sy = math.cos(yaw), math.sin(yaw)
    for v in bm.verts:
        q = Vector(v.co)
        local = Vector((q.x * size[0], q.y * size[1], q.z * size[2]))
        local += Vector((n3(q.x * 2 + seed, q.y * 2, q.z * 2), n3(q.x * 2, q.y * 2 + seed, q.z * 2), n3(q.x * 2, q.y * 2, q.z * 2 + seed))) * chip * min(size)
        p = Vector((local.x * cy - local.z * sy, local.y, local.x * sy + local.z * cy)) + Vector(center)
        b.vert(p, color(p, Vector((0, q.y * 2, 0)) + q.normalized() * .3))
    for f in bm.faces:
        b.face([base + v.index for v in f.verts], 0)
    bm.free()


def column(seed, height, radius=.42, broken=True):
    """Weathered column: plinth, one shaft with faint joints and entasis, broken top."""
    b = Builder()
    block(b, (0, .14, 0), (radius * 2.35, .28, radius * 2.35), seed, moss=.5, palette=RUIN)
    sides = 14
    joints = []
    y = .28
    while y < height:
        joints.append(y)
        y += .62
    rows = []
    steps_ = max(4, int((height - .28) / .16))
    for j in range(steps_ + 1):
        yy = .28 + (height - .28) * j / steps_
        near_joint = min(abs(yy - jy) for jy in joints) < .03 and j not in (0, steps_)
        rows.append((yy, .955 if near_joint else 1.0))
    color = stone_color(seed, .82, RUIN)
    rings = []
    for j, (yy, inset) in enumerate(rows):
        ring = []
        f = (yy - .28) / max(.01, height - .28)
        for i in range(sides):
            a = i * TAU / sides
            rr = radius * inset * (1 - .1 * f) * (1 - .035 * (i % 2))
            dy = 0.0
            if broken and j == len(rows) - 1:
                dy = -.35 * max(0, math.sin(a + seed)) ** 2 - .06 * (1 + n3(a * 2, seed, 0))
            p = Vector((math.cos(a) * rr, yy + dy, math.sin(a) * rr))
            ring.append(b.vert(p, color(p, Vector((math.cos(a) * .6, .5 * dy + (-.5 if yy < .5 else 0), math.sin(a) * .6)))))
        rings.append(ring)
    for lo, hi in zip(rings, rings[1:]):
        for i in range(sides):
            b.face([lo[i], lo[(i + 1) % sides], hi[(i + 1) % sides], hi[i]], 0)
    top = b.vert((0, height - (.2 if broken else 0), 0), mix(RUIN[1], MOSS[1], .55))
    for i in range(sides):
        b.face([rings[-1][i], rings[-1][(i + 1) % sides], top], 0)
    if broken:
        ivy(b, seed, Vector((radius * .2, height - .25, radius * .98)), height * .55)
    for i in range(4):  # rubble at the foot, kept inside the collider shadow
        a = i * TAU / 4 + .6
        block(b, (math.cos(a) * radius * 1.35, .07, math.sin(a) * radius * 1.35), (.22, .14, .18), seed + 30 + i, yaw=a, moss=.5, palette=RUIN)
    b.closed_slots = (0,)
    return b


def wall(seed, length, height, depth=.55, broken=.5):
    """Dry-stone wall in uneven courses, broken top, ivy patches."""
    rng = random.Random(seed)
    b = Builder()
    y = 0.0
    course = 0
    while y < height:
        ch = rng.uniform(.26, .36)
        x = -length / 2 + (course % 2) * .25
        while x < length / 2 - .1:
            w = rng.uniform(.4, .7)
            w = min(w, length / 2 - x)
            top_limit = height * (1 - broken * max(0, math.sin((x / length) * 3.2 + seed)) ** 2)
            if y + ch * .5 < top_limit:
                block(b, (x + w / 2, y + ch / 2, rng.uniform(-.03, .03)), (w - .025, ch - .02, depth * rng.uniform(.9, 1.05)), seed * 31 + course * 7 + int(x * 10), yaw=rng.uniform(-.04, .04), moss=.4 if y + ch > top_limit - .3 else 1.0, palette=RUIN)
            x += w
        y += ch
        course += 1
    ivy(b, seed, Vector((-length * .25, height * .9, depth * .52)), height * .8, mat=1)
    b.closed_slots = (0,)
    return b


def ivy(b, seed, start, length, mat=1):
    rng = random.Random(seed)
    for s in range(3):
        p = Vector(start) + Vector((s * .22 + rng.uniform(-.1, .1), rng.uniform(-.1, .05), 0))
        for j in range(int(length / .09)):
            p = p + Vector((rng.uniform(-.05, .05), -.09, 0))
            if rng.random() < .8:
                leaf(b, p + Vector((0, 0, .02)), Vector((0, .2, 1)).normalized(), Vector((rng.uniform(-1, 1), -.6, .2)).normalized(), rng.uniform(.1, .15), mix(MOSS[0], MOSS[2], rng.uniform(.1, .9)), mat)


def arch(seed):
    """Broken gateway: two piers, a partial arch of voussoirs, ivy curtain."""
    b = Builder()
    rng = random.Random(seed)
    for side in (-1, 1):
        rows = 6 if side < 0 else 4
        for r in range(rows):
            block(b, (side * 1.25, .2 + r * .4, 0), (.62, .38, .62), seed + r * 3 + side, yaw=rng.uniform(-.03, .03), moss=.75, palette=RUIN)
    span = 1.25
    for i in range(7):  # left part survives, right half collapsed
        a = math.pi - (i + .5) * math.pi / 11
        c = Vector((span * math.cos(a), 2.6 + span * .95 * math.sin(a), 0))
        block(b, c, (.36, .5, .6), seed + 40 + i, moss=.55, palette=RUIN)
    for i in range(5):
        block(b, (1.6 + i * .32, .1, .5 + .3 * math.sin(i * 2)), (.36, .2, .3), seed + 60 + i, yaw=i * .7, moss=.3)
    ivy(b, seed, Vector((-1.45, 3.0, .33)), 1.9)
    b.closed_slots = (0,)
    return b


def steps(seed, width=3.4, count=4):
    b = Builder()
    rng = random.Random(seed)
    for k in range(count):
        x = -width / 2
        while x < width / 2 - .05:
            w = rng.uniform(.5, .9)
            w = min(w, width / 2 - x)
            if rng.random() > .12:  # a few missing stones
                block(b, (x + w / 2, .1 + k * .2, -k * .42), (w - .03, .22, .5), seed + k * 17 + int(x * 10), yaw=rng.uniform(-.05, .05), moss=.5, palette=RUIN)
            x += w
    b.closed_slots = (0,)
    return b


def log(seed, length, radius):
    b = Builder()
    color = bark_color(BARK_GREY, seed)
    pts = [Vector((-length / 2 + length * t, radius * .9, .08 * math.sin(t * 3 + seed))) for t in [i / 5 for i in range(6)]]

    def mossy(p, a, t):
        rgb = color(p, a, t)
        up = math.sin(a)
        return mix(rgb, MOSS[1], smooth(.2, .8, up) * .8)
    tube(b, pts, [radius * (1 - .1 * t) for t in [i / 5 for i in range(6)]], mossy, sides=9, seed=seed)
    b.closed_slots = (0,)
    return b


def pavement(seed):
    """Worn flagstones: irregular running-bond rows in the plaza and approach, with gaps."""
    b = Builder()
    rng = random.Random(seed)
    (cx, cz), radius = PLAZA

    def inside(x, z):
        plaza = math.hypot((x - cx) / radius, (z - cz) / (radius * .9)) < 1 - .12 * n3(x, z, 3)
        t = max(0, min(1, (z - .7) / (-1.6 - .7)))
        ax = -.75 * (1 - t)
        approach = -1.7 < z < .6 and abs(x - ax) < .62
        return plaza or approach
    z = -5.6
    row = 0
    while z < .8:
        depth = rng.uniform(.42, .56)
        x = -2.6 + (row % 2) * .27 + rng.uniform(-.1, .1)
        while x < 2.6:
            w = rng.uniform(.45, .78)
            cxs, czs = x + w / 2, z + depth / 2
            if inside(cxs, czs) and rng.random() > .12:
                worn = rng.random()
                block(b, (cxs, -.005 + rng.uniform(0, .02), czs), (w - .07, .08, depth - .07), int(cxs * 1000 + czs * 100) + seed,
                      yaw=rng.uniform(-.06, .06), moss=1.55 - .45 * worn, chip=.2, palette=PAVE)
            x += w
        z += depth
        row += 1
    b.closed_slots = (0,)
    return b



# ------------------------------------------------------------ narrative props
CLOTH = (H('3f5a74'), H('5d7a96'), H('8aa2b4'))
WOOD = (H('4d3423'), H('7a5636'), H('9c7650'))


def plank_box(b, center, size, seed, yaw=0.0):
    """Wooden crate: board faces with darker seams and a lighter rim."""
    rng = random.Random(seed)
    for k in range(3):
        h = size[1] / 3
        c = Vector(center) + Vector((0, -size[1] / 2 + h * (k + .5), 0))
        block(b, c, (size[0], h - .015, size[2]), seed + k, yaw=yaw, moss=2, chip=.05, palette=WOOD)
    for sx in (-1, 1):
        for sz in (-1, 1):
            c = Vector(center) + Vector((sx * size[0] * .47 * math.cos(yaw) - sz * size[2] * .47 * math.sin(yaw), 0, sx * size[0] * .47 * math.sin(yaw) + sz * size[2] * .47 * math.cos(yaw)))
            block(b, c, (.05, size[1] + .02, .05), seed + 9, yaw=yaw, moss=2, chip=.02, palette=(H('3a2618'), H('5a3d27'), H('6e4c31')))


def prop_camp():
    """Abandoned camp: bedroll, pack, crate, badge, cup and a cold fire ring."""
    b = Builder()
    cloth = lambda p, u: mix(CLOTH[0], CLOTH[2], .3 + .5 * max(0, u.y) + .1 * n3(p.x * 5, p.y * 5, p.z * 5))
    blob(b, (.05, .07, 0), (.62, .07, .32), 301, cloth, subdiv=3, rough=.25, flat=-.9)
    roll = [Vector((-.55, .13, -.3)), Vector((-.55, .14, 0)), Vector((-.55, .13, .3))]
    tube(b, roll, [.12, .13, .12], lambda p, a, t: mix(H('a37f4c'), H('c9a56a'), .5 + .5 * math.sin(a * 3)), sides=10)
    blob(b, (-.15, .2, .42), (.2, .2, .16), 303, lambda p, u: mix(H('5a4430'), H('8a6a45'), .3 + .5 * max(0, u.y)), subdiv=2, rough=.3)
    plank_box(b, (.68, .2, -.45), (.46, .4, .4), 305, yaw=.25)
    blob(b, (.2, .16, .08), (.06, .03, .06), 307, lambda p, u: mix(H('8a6a2a'), H('e3c779'), .4 + .6 * max(0, u.y)), subdiv=2, rough=.1)
    tube(b, [Vector((.42, .0, .2)), Vector((.42, .11, .2))], [.04, .045], lambda p, a, t: H('b9b0a0'), sides=8)
    for i in range(7):  # fire ring stones and ash at the legacy fire position
        a = i * TAU / 7
        blob(b, (math.cos(a) * .34, .07, math.sin(a) * .34 - .9), (.11, .08, .1), 310 + i, stone_color(310 + i, 1.2), subdiv=2, rough=.6)
    blob(b, (0, .0, -.9), (.27, .03, .27), 320, lambda p, u: mix(H('2c2826'), H('5a534c'), .5 + .5 * n3(p.x * 7, 0, p.z * 7)), subdiv=2, rough=.2)
    for i in range(3):
        a = i * 1.9
        d = Vector((math.cos(a), 0, math.sin(a)))
        tube(b, [Vector((0, .04, -.9)) - d * .22, Vector((0, .06, -.9)) + d * .22], [.035, .035], lambda p, a_, t: mix(H('1d1714'), H('4a3528'), t), sides=6)
    tube(b, [Vector((-.2, .05, -1.0)), Vector((.2, .05, -.8))], [.035, .03], bark_color(BARK, 5), sides=6)
    b.closed_slots = ()
    return b


def prop_tablet():
    """The existing inscription stele, eroded; keeps the same five carved lines."""
    b = Builder()
    rng = random.Random(401)
    bm_c = Vector((0, .5, 0))
    block(b, (0, .5, 0), (.85, .98, .24), 401, moss=.62, chip=.16, palette=RUIN)
    block(b, (0, .04, .02), (1.05, .12, .5), 402, moss=.3, chip=.2, palette=RUIN)
    for i in range(5):
        w = .35 + .12 * math.sin(i)
        y = .75 - i * .12
        tilt = .14 * (1 if i % 2 == 0 else -1)
        x0, x1 = -w / 2, w / 2
        p0 = Vector((x0, y - x0 * tilt, .125))
        p1 = Vector((x1, y - x1 * tilt, .125))
        up = Vector((0, .014, 0))
        ids = [b.vert(p0 - up, H('3e4a42')), b.vert(p1 - up, H('3e4a42')), b.vert(p1 + up, H('4f6158')), b.vert(p0 + up, H('4f6158'))]
        b.face(ids, 0)
    ivy(b, 403, Vector((-.4, .95, .13)), .7, mat=0)
    b.closed_slots = ()
    return b


def prop_crystal_rock():
    """Base of the crystal fragment: cracked rock and three blackened roots."""
    b = Builder()
    blob(b, (0, .12, 0), (.5, .2, .45), 501, stone_color(501, .5), subdiv=3, rough=1.2, flat=-.3)
    color = lambda p, a, t: mix(H('1f1c1a'), H('3b3530'), .5 + .5 * math.sin(a * 3))
    for i in range(3):
        a = i * TAU / 3 + .3
        d = Vector((math.cos(a), 0, math.sin(a)))
        pts = bezier(d * .25 + Vector((0, .1, 0)), d * .6 + Vector((0, .12, 0)), d * .95 + Vector((0, -.05, 0)) + d.cross(Vector((0, 1, 0))) * .2, 5)
        tube(b, pts, [.06, .055, .05, .04, .03, .02], color, sides=6, cap=False)
    b.closed_slots = ()
    return b


# ----------------------------------------------------------------- terrain
def dist_to_paths(x, z):
    best = 1e9
    for pts, _w in PATHS:
        for (ax, az), (bx, bz) in zip(pts, pts[1:]):
            dx, dz = bx - ax, bz - az
            t = max(0, min(1, ((x - ax) * dx + (z - az) * dz) / (dx * dx + dz * dz)))
            best = min(best, math.hypot(x - ax - t * dx, z - az - t * dz))
    return best


def terrain_height(x, z):
    dx = max(abs(x) - PLAY_X, 0)
    dz = max(-z - PLAY_Z, 0) if z < 0 else max(z - PLAY_Z, 0)
    d = math.hypot(dx, dz)
    if d <= 0:
        return 0.0
    n1 = n3(x * .16, z * .16, .3)
    n2 = n3(x * .45, z * .45, 2.1)
    h = smooth(0, 3.2, d) * (.75 + .45 * n1) + smooth(1, 9, d) * (1.1 + .9 * n1) + .25 * smooth(0, 2, d) * n2
    h += smooth(-8, -18, z) * smooth(0, 5, d) * 2.2
    if z > PLAY_Z:
        h *= .45
    carve = math.exp(-(dist_to_paths(x, z) / 1.5) ** 2)
    return h * (1 - .72 * carve)


def terrain():
    b = Builder()
    xs = np.arange(TERRAIN_X[0], TERRAIN_X[1] + .01, .8)
    zs = np.arange(TERRAIN_Z[0], TERRAIN_Z[1] + .01, .8)
    for z in zs:
        for x in xs:
            b.vert((float(x), terrain_height(float(x), float(z)) - .004, float(z)), (1, 1, 1))
    nx = len(xs)
    for j in range(len(zs) - 1):
        for i in range(nx - 1):
            a = j * nx + i
            b.face([a, a + nx, a + nx + 1, a + 1], 0)
    b.closed_slots = ()
    return b


def vnoise(rng, shape, cells):
    h, w = shape
    g = rng.random((cells[0] + 2, cells[1] + 2))
    y = np.linspace(0, cells[0], h, endpoint=False)
    x = np.linspace(0, cells[1], w, endpoint=False)
    y0, x0 = y.astype(int), x.astype(int)
    fy, fx = y - y0, x - x0
    fy, fx = fy * fy * (3 - 2 * fy), fx * fx * (3 - 2 * fx)
    a, b_ = g[y0][:, x0], g[y0][:, x0 + 1]
    c, d = g[y0 + 1][:, x0], g[y0 + 1][:, x0 + 1]
    top = a + (b_ - a) * fx[None, :]
    bot = c + (d - c) * fx[None, :]
    return top + (bot - top) * fy[:, None]


def fbm(rng, shape, base, octaves=5):
    out = np.zeros(shape)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        cells = (base[0] * 2 ** o, base[1] * 2 ** o)
        out += amp * vnoise(rng, shape, cells)
        total += amp
        amp *= .5
    return out / total


def save_png(name, rgb):
    h, w = rgb.shape[:2]
    rgba = np.ones((h, w, 4), np.float32)
    rgba[:, :, :3] = np.clip(rgb, 0, 1)
    img = bpy.data.images.new(name, width=w, height=h, alpha=False)
    img.colorspace_settings.name = 'sRGB'
    img.pixels.foreach_set(np.flipud(rgba).ravel())  # Blender rows start at the bottom
    img.filepath_raw = str(OUT / (name + '.png'))
    img.file_format = 'PNG'
    img.save()
    bpy.data.images.remove(img)


def paint_ground(tree_spots):
    """Painted ground map in sRGB. Row 0 = north (PAINT_Z[0]); sampled by world XZ in Godot."""
    size = 2048
    rng = np.random.default_rng(11)
    xs = np.linspace(PAINT_X[0], PAINT_X[1], size, endpoint=False) + (PAINT_X[1] - PAINT_X[0]) / size / 2
    zs = np.linspace(PAINT_Z[0], PAINT_Z[1], size, endpoint=False) + (PAINT_Z[1] - PAINT_Z[0]) / size / 2
    X, Z = np.meshgrid(xs, zs)
    big = fbm(rng, (size, size), (6, 6), 4)
    med = fbm(rng, (size, size), (40, 40), 3)
    fine = fbm(rng, (size, size), (220, 220), 2)
    c = lambda h: np.array(hexrgb(h))[None, None, :]
    grass = c('4b7a2b') * (1 - big[..., None]) + c('77a03a') * big[..., None]
    grass = grass * (1 - .5 * med[..., None]) + c('93b447') * .5 * med[..., None] * (big[..., None] > .55)
    grass *= (.9 + .2 * fine[..., None])
    # Path distance field with frayed edges.
    dist = np.full(X.shape, 99.0)
    for pts, width in PATHS:
        for (ax, az), (bx, bz) in zip(pts, pts[1:]):
            dx, dz = bx - ax, bz - az
            t = np.clip(((X - ax) * dx + (Z - az) * dz) / (dx * dx + dz * dz), 0, 1)
            dist = np.minimum(dist, np.hypot(X - ax - t * dx, Z - az - t * dz) / width)
    (pcx, pcz), pr = PLAZA
    dist = np.minimum(dist, np.hypot(X - pcx, (Z - pcz) / .9) / pr)
    edge = dist + (med - .5) * .55 + (fine - .5) * .25
    path_mask = 1 - np.clip((edge - .62) / .3, 0, 1)
    path_mask = path_mask * path_mask * (3 - 2 * path_mask)
    dirt = c('a8875a') * (1 - med[..., None]) + c('c3a271') * med[..., None]
    dirt = dirt * (.9 + .18 * fine[..., None])
    trodden = np.clip(1 - dist / .45, 0, 1)[..., None]
    dirt = dirt * (1 - .12 * trodden) + c('8f6f49') * .12 * trodden
    rim = np.exp(-((edge - .78) / .12) ** 2)[..., None]
    rgb = grass * (1 - path_mask[..., None]) + dirt * path_mask[..., None]
    rgb *= (1 - .18 * rim)
    # Shade, moss and litter around trunks: grounds the trees.
    shade = np.zeros(X.shape)
    for (tx, tz), r in tree_spots:
        shade = np.maximum(shade, np.exp(-((X - tx) ** 2 + (Z - tz) ** 2) / (r * r)))
    litter = (fine > .62) & (shade > .25) & (rng.random(X.shape) < .5)
    rgb = rgb * (1 - .28 * shade[..., None]) + c('2f4f2a') * .28 * shade[..., None]
    rgb = np.where(litter[..., None], rgb * .6 + c('9b6a35') * .4, rgb)
    # Outside the walkable clearing: deeper forest floor.
    out = np.clip((np.maximum(np.abs(X) - PLAY_X, np.abs(Z + .0) - PLAY_Z)) / 3.5, 0, 1)
    out = (out * out * (3 - 2 * out))[..., None]
    floor = c('3d6230') * (1 - big[..., None]) + c('5b7d34') * big[..., None]
    rgb = rgb * (1 - .65 * out * (1 - path_mask[..., None])) + floor * .65 * out * (1 - path_mask[..., None])
    # Clover / small flower speckles and pebbles.
    speck = rng.random(X.shape)
    rgb = np.where(((speck < .0016) & (path_mask < .2))[..., None], c('e9e4c7'), rgb)
    rgb = np.where(((speck > .9984) & (path_mask < .2))[..., None], c('f0cf55'), rgb)
    pebbles = (speck > .4) & (speck < .4015) & (path_mask > .6)
    rgb = np.where(pebbles[..., None], c('d9cdb0'), rgb)
    save_png('ground_paint', rgb)
    # Tileable stroke texture (grey, 0.5 = neutral) for close-up variation.
    t = 512
    detail = np.full((t, t), .5)
    r2 = np.random.default_rng(5)
    for _ in range(9000):
        x0, y0 = r2.integers(0, t, 2)
        ang = -math.pi / 2 + r2.normal(0, .35)
        length = r2.integers(5, 13)
        val = r2.choice([.22, .35, .68, .82])
        for s in range(length):
            xi = int(x0 + math.cos(ang) * s) % t
            yi = int(y0 + math.sin(ang) * s) % t
            detail[yi, xi] = detail[yi, xi] * .4 + val * .6
    save_png('ground_detail', np.repeat(detail[..., None], 3, axis=2))


# ------------------------------------------------------------------- layout
KIT = {}
COUNTS = {}


def add_kit(name, builder, mats):
    data = builder.mesh(name, mats)
    KIT[name] = data
    return data


def place(kit, pos, yaw=0.0, scale=1.0, prefix='', y=None):
    data = KIT[kit]
    x, z = pos
    yy = terrain_height(x, z) if y is None else y
    obj = bpy.data.objects.new((prefix + kit), data)
    obj.location = to_blender((x, yy, z))
    obj.rotation_euler = (0, 0, yaw)
    obj.scale = (scale, scale, scale)
    bpy.context.scene.collection.objects.link(obj)
    COUNTS[prefix + kit] = COUNTS.get(prefix + kit, 0) + 1
    return obj


def clear_of_gameplay(x, z, margin=0.0):
    for (px, pz), r in KEEP_CLEAR:
        if math.hypot(x - px, z - pz) < r + margin:
            return False
    return dist_to_paths(x, z) > .85 + margin


# Fixed gameplay camera (world/forest_art.gd). Far trees fully outside its
# widest frustum (20:9 phones + margin) are never seen in play: skip them.
CAMERA = (Vector((0, 18.5, 14.5)), Vector((0, 0, -.8)), 40.0, 2.3)


def in_gameplay_view(p, radius):
    eye, target, fov, aspect = CAMERA
    f = (target - eye).normalized()
    r = f.cross(Vector((0, 1, 0))).normalized()
    u = r.cross(f)
    d = Vector(p) - eye
    depth = d.dot(f)
    if depth <= -radius:
        return False
    t = math.tan(math.radians(fov / 2))
    return abs(d.dot(u)) - radius * 1.2 < t * depth and abs(d.dot(r)) - radius * 1.2 < t * aspect * depth


def inside_play(x, z, margin=0.0):
    return abs(x) < PLAY_X - margin and abs(z) < PLAY_Z - margin


def build_kit():
    add_kit('TreeBroadA', tree_broad(3, 3.0, .36, 1.75, LEAF_SPRING, lean=(.25, -.1)), ['Bark', 'Foliage'])
    add_kit('TreeBroadB', tree_broad(8, 2.6, .34, 1.5, LEAF_WARM, lean=(-.2, .15), clumps=6), ['Bark', 'Foliage'])
    add_kit('TreeBroadC', tree_broad(14, 3.4, .38, 1.9, LEAF_DEEP, lean=(.45, .1), clumps=8), ['Bark', 'Foliage'])
    add_kit('TreeYoung', tree_broad(33, 3.3, .34, 1.15, LEAF_SPRING, lean=(.1, -.25), clumps=5), ['Bark', 'Foliage'])
    add_kit('TreeFarBroad', tree_broad(21, 3.2, .34, 1.9, LEAF_DEEP, clumps=5, full=False, leaf_size=.55, density=.55), ['Bark', 'Foliage'])
    add_kit('TreeFarBroadB', tree_broad(26, 2.6, .3, 1.6, LEAF_SPRING, clumps=4, full=False, leaf_size=.55, density=.55), ['Bark', 'Foliage'])
    add_kit('PineA', tree_pine(4, 7.0, 2.2, 7), ['Bark', 'Foliage'])
    add_kit('PineB', tree_pine(9, 5.6, 1.9, 6, palette=(H('1d3a2c'), H('2c5a3a'), H('4f8642'), H('7fa957'))), ['Bark', 'Foliage'])
    add_kit('PineFar', tree_pine(17, 7.5, 2.4, 5, palette=(H('1d382b'), H('2d573a'), H('467945'), H('6a9452')), full=False, points=8), ['Bark', 'Foliage'])
    add_kit('TreeAncient', tree_ancient(), ['Bark', 'Foliage'])
    add_kit('BushA', bush(31, 1.0, LEAF_SPRING), ['Foliage'])
    add_kit('BushB', bush(37, .8, LEAF_DEEP), ['Foliage'])
    add_kit('BushWarm', bush(41, .9, LEAF_WARM), ['Foliage'])
    add_kit('Fern', fern(5, .75), ['Plant'])
    add_kit('Grass', grass(7, 1.0), ['Plant'])
    add_kit('GrassTall', grass(12, 1.5, (H('2f5a2a'), H('6c9f3a'), H('b2c95e'))), ['Plant'])
    add_kit('FlowersWhite', flowers(1, H('f4f1e4')), ['Plant', 'Bloom'])
    add_kit('FlowersYellow', flowers(2, H('f2c84b'), H('c46a2b')), ['Plant', 'Bloom'])
    add_kit('FlowersRed', flowers(3, H('e0563a'), H('f6d36b'), count=5), ['Plant', 'Bloom'])
    add_kit('Lupins', flowers(4, H('8a6bd1'), count=5, spike=True), ['Plant', 'Bloom'])
    add_kit('Mushrooms', mushrooms(6), ['Bloom'])
    add_kit('RockA', boulder(51, (1.5, 1.05, 1.15)), ['Stone'])
    add_kit('RockB', boulder(52, (1.25, 1.3, 1.45), .4), ['Stone'])
    add_kit('RockSmall', boulder(53, (.55, .38, .45), .35), ['Stone'])
    add_kit('ColumnTall', column(61, 2.75), ['Stone'])
    add_kit('ColumnShort', column(62, 1.95), ['Stone'])
    add_kit('ColumnStub', column(63, .9), ['Stone'])
    add_kit('Wall', wall(71, 3.2, 1.25), ['Stone', 'Plant'])
    add_kit('WallLow', wall(72, 2.4, .7, broken=.7), ['Stone', 'Plant'])
    add_kit('Arch', arch(81), ['Stone', 'Plant'])
    add_kit('Steps', steps(91), ['Stone'])
    add_kit('Log', log(95, 2.4, .26), ['Bark'])
    add_kit('Pavement', pavement(99), ['Stone'])
    add_kit('Terrain', terrain(), ['Ground'])
    add_kit('PropCamp', prop_camp(), ['Stone'])
    add_kit('PropTablet', prop_tablet(), ['Stone'])
    add_kit('PropCrystalRock', prop_crystal_rock(), ['Stone'])


def layout():
    rng = random.Random(2026)
    # Single placement of location-specific meshes.
    place('Terrain', (0, 0), y=0)
    place('Pavement', (0, 0), y=0)
    for kit, at in [('PropCamp', (-4.5, 2)), ('PropTablet', (-2.4, -2.2)), ('PropCrystalRock', (3.1, -.5))]:
        place(kit, at, y=0)
    # Hero trees dress the nine original trunk colliders.
    hero = {(-7, -4.5): ('PineA', 1.0), (-7.4, 0): ('TreeBroadC', 1.05), (-7.3, 4.8): ('TreeYoung', 1.0),
            (-3.5, -4.7): ('TreeBroadA', 1.0), (0, -5): ('TreeAncient', 1.0), (3.4, -5.2): ('PineB', 1.05),
            (7.1, -4.6): ('TreeBroadA', 1.1), (7.2, 0): ('PineA', .92), (7.2, 4.7): ('TreeYoung', .95)}
    for (x, z), (kit, s) in hero.items():
        place(kit, (x, z), yaw=rng.uniform(0, TAU) if kit != 'TreeAncient' else .0, scale=s, y=0)
    # Original rock colliders.
    place('RockA', ROCK_COLLIDERS[0][0], yaw=.3, y=0)
    place('RockB', ROCK_COLLIDERS[1][0], yaw=1.9, y=0)
    # Columns flanking the approach to the ruins.
    place('ColumnTall', COLUMNS[0], yaw=.2, y=0)
    place('ColumnShort', COLUMNS[1], yaw=1.1, y=0)
    # Ruin backdrop: steps up the north bank behind the ancient tree, walls, arch.
    place('Steps', (0, -6.9), y=terrain_height(0, -6.9) - .05)
    for x, z, yaw, kit in [(-2.6, -7.0, .05, 'Wall'), (2.9, -7.2, -.08, 'Wall'), (-8.7, -2.6, 1.57, 'WallLow'), (8.8, 2.4, -1.57, 'WallLow'),
                           (5.7, -7.6, .3, 'WallLow'), (-6.0, -7.4, -.2, 'WallLow')]:
        place(kit, (x, z), yaw=yaw)
    place('Arch', (-4.6, -9.2), yaw=.12)
    for x, z in [(4.6, -8.6), (-1.6, -8.7), (8.9, -2.9), (8.9, -1.4), (-8.9, 1.2)]:
        place('ColumnStub', (x, z), yaw=rng.uniform(0, TAU), scale=rng.uniform(.85, 1.1))
    place('ColumnTall', (1.9, -9.6), yaw=.4, scale=.95)
    place('Log', (-9.4, 3.3), yaw=1.3)
    place('Log', (9.6, -5.6), yaw=-.4, scale=.9)
    # Edge massing: bushes/rocks in the boundary band; never inside the walkable rect.
    def edge_points(step):
        pts = []
        for i in range(int(2 * (PLAY_X + 2) / step) + 1):
            x = -PLAY_X - 2 + i * step
            pts += [(x, -PLAY_Z - .9), (x, PLAY_Z + .8)]
        for i in range(int(2 * (PLAY_Z + 1) / step) + 1):
            z = -PLAY_Z - 1 + i * step
            pts += [(-PLAY_X - .9, z), (PLAY_X + .9, z)]
        return pts
    for x, z in edge_points(1.35):
        x += rng.uniform(-.35, .35)
        z += rng.uniform(-.3, .3)
        if dist_to_paths(x, z) < 1.4 or (abs(x) < 3.6 and z < -6):
            continue
        if z > PLAY_Z and abs(x) < 7.5 and rng.random() < .55:
            continue  # keep the near edge lower so it frames instead of hiding
        kit = rng.choice(['BushA', 'BushB', 'BushWarm', 'BushA', 'Fern', 'RockSmall'])
        place(kit, (x, z), yaw=rng.uniform(0, TAU), scale=rng.uniform(.85, 1.35))
    # Second band: forest edge trees on the banks (casting shadows towards the clearing).
    for x, z, kit, s in [(-10.6, -6.2, 'TreeBroadA', 1.2), (-11.2, 2.6, 'PineB', 1.1), (-12.5, -1.6, 'TreeBroadB', 1.25),
                         (10.6, -2.2, 'TreeBroadC', 1.15), (11.4, 4.2, 'PineA', 1.0), (12.4, -6.8, 'PineB', 1.2),
                         (-8.2, -9.6, 'PineA', 1.15), (8.6, -9.2, 'TreeBroadB', 1.2), (-1.8, -11.6, 'PineB', 1.3), (3.6, -11.0, 'TreeBroadC', 1.2),
                         (-6.6, -12.4, 'TreeBroadC', 1.3), (6.3, -13.4, 'PineA', 1.25)]:
        place(kit, (x, z), yaw=rng.uniform(0, TAU), scale=s)
    # Far forest: denser, cheaper, darker. Rejection sampled on the banks.
    tries = 0
    far = []
    while len(far) < 95 and tries < 8000:
        tries += 1
        x, z = rng.uniform(-30, 30), rng.uniform(-33, 12)
        dx = max(abs(x) - PLAY_X, 0)
        dz = max(-z - PLAY_Z, 0) if z < 0 else max(z - PLAY_Z, 0)
        d = math.hypot(dx, dz)
        if d < 4.2 or dist_to_paths(x, z) < 2.0 or (z > 9 and abs(x) < 14):
            continue
        if any(math.hypot(x - a, z - c) < 2.3 for a, c in far):
            continue
        if not in_gameplay_view((x, terrain_height(x, z) + 5, z), 5.5):
            continue
        far.append((x, z))
        kit = rng.choice(['PineFar', 'PineFar', 'TreeFarBroad', 'TreeFarBroadB', 'PineFar'])
        place(kit, (x, z), yaw=rng.uniform(0, TAU), scale=rng.uniform(.95, 1.45), prefix='Far_')
    # Composed planting inside the clearing: clusters at colliders and path edges.
    clusters = [  # (centre, radius, [(kit, n)]) deliberate patches, not uniform noise
        ((-1.3, 4.8), 1.2, [('Fern', 2), ('FlowersRed', 2), ('Grass', 6)]),
        ((4.3, 3.3), 1.2, [('GrassTall', 4), ('FlowersYellow', 2), ('Fern', 1)]),
        ((-2.7, -1.5), .9, [('Fern', 2), ('Grass', 4)]),
        ((2.1, -1.5), .9, [('FlowersWhite', 2), ('Grass', 4), ('Mushrooms', 1)]),
        ((-7.4, 0), 1.3, [('Fern', 3), ('Mushrooms', 1), ('GrassTall', 3)]),
        ((7.2, 0), 1.3, [('Fern', 2), ('Lupins', 3), ('Grass', 4)]),
        ((-7.3, 4.8), 1.2, [('Fern', 2), ('FlowersWhite', 2), ('Mushrooms', 1)]),
        ((7.2, 4.7), 1.2, [('Lupins', 3), ('Grass', 4)]),
        ((-7, -4.5), 1.2, [('Fern', 3), ('GrassTall', 3)]),
        ((7.1, -4.6), 1.2, [('Fern', 2), ('FlowersYellow', 2)]),
        ((-3.5, -4.7), 1.2, [('Fern', 2), ('Mushrooms', 1), ('FlowersWhite', 1)]),
        ((3.4, -5.2), 1.1, [('Fern', 2), ('Grass', 4)]),
        ((0, -5.2), 1.6, [('Fern', 3), ('GrassTall', 3)]),
        ((-6.4, 5.9), 1.0, [('FlowersYellow', 2), ('Grass', 4)]),
        ((2.6, 5.5), 1.4, [('FlowersWhite', 3), ('Grass', 5), ('Lupins', 2)]),
        ((6.0, 5.9), 1.0, [('FlowersRed', 2), ('GrassTall', 3)]),
        ((-6.8, -2.4), 1.0, [('Lupins', 2), ('Grass', 4)]),
        ((5.6, -5.4), .9, [('Grass', 4), ('FlowersWhite', 1)]),
    ]
    for (cx, cz), r, items in clusters:
        for kit, n in items:
            for _ in range(n):
                for _try in range(12):
                    a, rr = rng.uniform(0, TAU), r * math.sqrt(rng.uniform(.2, 1))
                    x, z = cx + math.cos(a) * rr, cz + math.sin(a) * rr
                    tall = kit in ('Fern', 'Lupins', 'GrassTall')
                    if clear_of_gameplay(x, z, .05 if not tall else .25) and abs(x) < PLAY_X + .3 and abs(z) < PLAY_Z + .3:
                        place(kit, (x, z), yaw=rng.uniform(0, TAU), scale=rng.uniform(.8, 1.15))
                        break
    # Short grass sprinkled where it reads as meadow, thinning towards paths.
    for _ in range(1400):
        x, z = rng.uniform(-PLAY_X - 4, PLAY_X + 4), rng.uniform(-PLAY_Z - 4, PLAY_Z + 3)
        dpath = dist_to_paths(x, z)
        if dpath < 1.05 or not clear_of_gameplay(x, z, .1):
            continue
        density = .26 + .6 * smooth(1, 4, dpath) + (.35 if not inside_play(x, z) else 0)
        if rng.random() > density:
            continue
        place('Grass', (x, z), yaw=rng.uniform(0, TAU), scale=rng.uniform(.75, 1.3))
    # Small stones along trail edges.
    for pts, width in PATHS[:3]:
        for (ax, az), (bx, bz) in zip(pts, pts[1:]):
            for t in (.3, .75):
                if rng.random() < .55:
                    continue
                x, z = ax + (bx - ax) * t, az + (bz - az) * t
                nx, nz = -(bz - az), bx - ax
                ln = math.hypot(nx, nz)
                s = rng.choice((-1, 1)) * (width + .3)
                x, z = x + nx / ln * s, z + nz / ln * s
                if clear_of_gameplay(x, z, -.4) and not (abs(x) < 1 and -6 < z < -1):
                    place('RockSmall', (x, z), yaw=rng.uniform(0, TAU), scale=rng.uniform(.35, .6))


# -------------------------------------------------------------------- export
def mesh_metrics(g):
    out = {}
    for mesh in g['meshes']:
        prims = mesh['primitives']
        out[mesh['name']] = {
            'triangles': sum(g['accessors'][p['indices']]['count'] // 3 for p in prims),
            'vertices': sum(g['accessors'][p['attributes']['POSITION']]['count'] for p in prims),
            'surfaces': len(prims)}
    return out


def export():
    bpy.ops.object.select_all(action='SELECT')
    kwargs = dict(filepath=str(GLB), export_format='GLB', use_selection=False, export_animations=False, export_yup=True,
                  export_apply=False, export_normals=True, export_texcoords=False, export_materials='EXPORT')
    try:
        bpy.ops.export_scene.gltf(**kwargs, export_vertex_color='ACTIVE')
    except TypeError:
        bpy.ops.export_scene.gltf(**kwargs, export_colors=True)
    blob_ = GLB.read_bytes()
    n = struct.unpack_from('<I', blob_, 12)[0]
    g = json.loads(blob_[20:20 + n])
    metrics = mesh_metrics(g)
    counts = {}
    for node in g['nodes']:
        if 'mesh' in node:
            name = g['meshes'][node['mesh']]['name']
            counts[name] = counts.get(name, 0) + 1
    assert all('COLOR_0' in p['attributes'] for m in g['meshes'] for p in m['primitives']), 'vertex colours missing from export'
    total = sum(metrics[k]['triangles'] * counts.get(k, 0) for k in metrics)
    report = {
        'blender': bpy.app.version_string,
        'source': 'Original geometry, vertex colours and painted ground authored by tools/blender/build_eclipse_clearing.py; no third-party assets',
        'meshes': metrics, 'instances': counts, 'scene_triangles': total,
        'materials': sorted(m['name'] for m in g['materials']),
        'textures': {'ground_paint.png': [2048, 2048], 'ground_detail.png': [512, 512]},
        'glb_bytes': len(blob_), 'glb_sha256': sha(GLB), 'blend_sha256': sha(BLEND),
        'script_sha256': sha(Path(__file__)), 'mobile_tested': False}
    (OUT / 'eclipse_clearing_manifest.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print('ECLIPSE_CLEARING', json.dumps({'scene_triangles': total, 'nodes': sum(counts.values()), 'glb_bytes': len(blob_)}))


assert bpy.app.background, 'Use a separate background Blender process'
if '--export-only' in sys.argv:
    bpy.ops.wm.open_mainfile(filepath=str(BLEND))
else:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    make_materials()
    build_kit()
    layout()
    trees = [((x, z), 1.7) for x, z in TREE_COLLIDERS] + [((0, -5), 2.6)]
    paint_ground(trees)
    staged = OUT / 'eclipse_clearing.generated.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(staged), check_existing=False)
    staged.replace(BLEND)
export()
