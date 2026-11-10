"""Experimental 'PS1 battle model' variant of Kael, Lyra and Nira (iteration 1.2).

Art direction study of late-90s JRPG battle models: rigid sculpted parts per bone
(joints hidden by rounded overlaps, no skin stretching), ~5.8 heads, big hands,
boots, hair locks and weapons, painted palette swatches and a painted face.
Designs are original. Writes only to assets/characters/<hero>/ps1/.

Blender background CLI:
  blender --background --factory-startup --python-exit-code 1 --python tools/blender/build_ps1_party.py [-- --hero kael|lyra|nira] [--export-only]
--export-only reopens the saved .blend (keeps manual edits) and only re-exports.
"""
import bpy
import bmesh
import math
import json
import sys
import struct
import hashlib
from pathlib import Path
import numpy as np
from mathutils import Vector, Matrix, Euler, Quaternion

ROOT = Path(__file__).resolve().parents[2]
FPS = 60
TAU = math.tau
ATLAS = 512
SW = 32            # palette swatch size in pixels (8x8 grid in the left half)
FACE = (256, 0, 256, 256)   # x, y, w, h of the painted face region (image pixels, top-left origin)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def hexrgb(h):
    return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)])


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def lerp(a, b, t):
    return a + (b - a) * t


# ----------------------------------------------------------------- characters
# Original designs. Colours keep each hero's established identity.
HEROES = {
    'kael': dict(
        scale=1.0, sx=.255, hipx=.112, chest=1.0, hips=1.0, head=1.0,
        colors=dict(skin='e9b996', skin_sh='c98f6f', hair='6b3f26', hair_hi='8c5634', tunic='2c3f73', tunic_hi='3d5596',
                    under='a9b9d6', leather='7a4b2b', leather_dk='4e2f1d', metal='aeb8c4', metal_dk='6f7c8c', trousers='2a2c3d',
                    boots='5a3823', gold='d9b24f', blade='dfe6ee', blade_edge='f7fbff', grip='3b2a22', eye='5a3a22', lip='b06c5a'),
        eye='5a3a22'),
    'lyra': dict(
        scale=.965, sx=.205, hipx=.1, chest=.82, hips=1.02, head=1.0,
        colors=dict(skin='f0c8b0', skin_sh='d39f8b', hair='35264d', hair_hi='5a4482', tunic='7a62b8', tunic_hi='9a86d0',
                    under='2b2a4a', leather='3a2d3f', leather_dk='251c2a', metal='d9d4ea', metal_dk='8f88aa', trousers='272640',
                    boots='3a2d4a', gold='e2c66a', blade='9ed8f2', blade_edge='e8f8ff', grip='3a2d3f', eye='6a4fb0', lip='b9707a',
                    trim='e0cf96', cape='2f2d63', cape_in='1f1d40'),
        eye='6a4fb0'),
    'nira': dict(
        scale=.915, sx=.215, hipx=.108, chest=.86, hips=1.06, head=1.02,
        colors=dict(skin='e8b998', skin_sh='c99274', hair='9a4f2c', hair_hi='c06a3a', tunic='e7dcbc', tunic_hi='f4ecd3',
                    under='7d9a7b', leather='8a5a34', leather_dk='5c3a22', metal='c9b27a', metal_dk='8f7a4c', trousers='5d4634',
                    boots='6b4428', gold='d6b25c', blade='b8e6a6', blade_edge='effbe6', grip='6b4a2e', eye='3f7a4f', lip='b8695a',
                    cape='7f9c7e', cape_in='5b7458', trim='c9a462'),
        eye='3f7a4f'),
}


def landmarks(hero):
    s = HEROES[hero]['scale']
    sx = HEROES[hero]['sx']
    hx = HEROES[hero]['hipx']
    L = dict(ankle=.105 * s, knee=.545 * s, hip=1.0 * s, waist=1.21 * s, shoulder_z=1.555 * s, neck=1.615 * s,
             chin=1.705 * s, top=2.065 * s, sx=sx, hx=hx)
    L['elbow'] = Vector((sx + .045, .02, L['shoulder_z'] - .305 * s))
    L['wrist'] = Vector((sx + .075, -.02, L['shoulder_z'] - .565 * s))
    L['hand_tip'] = Vector((sx + .085, -.035, L['shoulder_z'] - .705 * s))
    return L


# ------------------------------------------------------------------- palette
class Palette:
    def __init__(self, colors):
        self.names = list(colors.keys())
        self.colors = colors

    def index(self, name):
        return self.names.index(name)

    def uv(self, name, t=.5, s=.5):
        """UV inside a swatch; t = 0 light (top) .. 1 shade (bottom)."""
        i = self.index(name)
        row, col = divmod(i, 8)
        x = col * SW + 4 + s * (SW - 8)
        y = row * SW + 4 + max(0, min(1, t)) * (SW - 8)
        return (x / ATLAS, 1 - y / ATLAS)


def paint_atlas(hero, pal, face_spec, out):
    img = np.zeros((ATLAS, ATLAS, 3), np.float32)
    rng = np.random.default_rng(len(hero))
    yy, xx = np.mgrid[0:SW, 0:SW].astype(np.float32) / (SW - 1)
    for name in pal.names:
        i = pal.index(name)
        row, col = divmod(i, 8)
        base = hexrgb(pal.colors[name])
        # Light top, cool shaded bottom, soft vertical brush streaks: painted, not flat.
        shade = 1.1 - .3 * yy
        streak = .03 * np.sin(xx * 19 + rng.uniform(0, 6)) * (1 - yy * .5)
        cool = np.array([.97, .99, 1.04])
        sw = base[None, None, :] * (shade + streak)[..., None]
        sw = sw * (1 - .4 * yy[..., None]) + sw * cool[None, None, :] * .4 * yy[..., None]
        img[row * SW:(row + 1) * SW, col * SW:(col + 1) * SW] = sw
    paint_face(img, hero, pal, face_spec)
    rgba = np.ones((ATLAS, ATLAS, 4), np.float32)
    rgba[..., :3] = np.clip(img, 0, 1)
    image = bpy.data.images.new(hero.title() + 'PS1Atlas', width=ATLAS, height=ATLAS, alpha=False)
    image.pixels.foreach_set(np.flipud(rgba).ravel())
    image.filepath_raw = str(out / (hero + '_atlas.png'))
    image.file_format = 'PNG'
    image.save()
    image.pack()
    image.filepath_raw = '//' + hero + '_atlas.png'
    return image


def paint_face(img, hero, pal, spec):
    """Painted face in the head's front projection. Supersampled ellipse masks."""
    fx, fy, fw, fh = FACE
    ss = 3
    H, W = fh * ss, fw * ss
    py, px = np.mgrid[0:H, 0:W].astype(np.float32)
    # Face-space coordinates in metres matching head_uv().
    X = -spec['w'] + (px + .5) / W * 2 * spec['w']
    Z = spec['ztop'] - (py + .5) / H * (spec['ztop'] - spec['zbot'])
    c = pal.colors
    skin = hexrgb(c['skin'])
    out = np.ones((H, W, 3), np.float32) * skin
    # Soft shading toward the jaw sides and a little blush.
    side = np.clip(np.abs(X) / spec['w'], 0, 1)
    out *= (1 - .16 * side ** 2)[..., None]
    blush = np.exp(-(((np.abs(X) - spec['eye_x'] * 1.05) / .022) ** 2 + ((Z - spec['eye_z'] + .045) / .014) ** 2))
    out = out * (1 - .22 * blush[..., None]) + hexrgb('e58c7f') * .22 * blush[..., None]

    def ell(cx, cz, rx, rz, rot=0.0):
        dx, dz = X - cx, Z - cz
        ca, sa = math.cos(rot), math.sin(rot)
        u, v = dx * ca + dz * sa, -dx * sa + dz * ca
        return (u / rx) ** 2 + (v / rz) ** 2

    def put(mask, rgb, alpha=1.0):
        nonlocal out
        out = out * (1 - alpha * mask[..., None]) + np.asarray(rgb)[None, None, :] * alpha * mask[..., None]

    ex, ez, ew, eh = spec['eye_x'], spec['eye_z'], spec['eye_w'], spec['eye_h']
    iris = hexrgb(spec['iris'])
    for sgn in (-1, 1):
        cx = sgn * ex
        tilt = sgn * spec.get('tilt', .12)
        white = ell(cx, ez, ew, eh, tilt) < 1
        put(white.astype(np.float32), hexrgb('f6f2ea'))
        ir = (ell(cx - sgn * ew * .08, ez - eh * .1, ew * .52, eh * .95, 0) < 1) & white
        put(ir.astype(np.float32), iris * .85)
        irc = (ell(cx - sgn * ew * .08, ez - eh * .25, ew * .36, eh * .55, 0) < 1) & white
        put(irc.astype(np.float32), np.clip(iris * 1.35, 0, 1), .55)
        pup = (ell(cx - sgn * ew * .08, ez - eh * .05, ew * .2, eh * .45, 0) < 1) & white
        put(pup.astype(np.float32), hexrgb('1b1622'))
        hl = ell(cx - sgn * ew * .25, ez + eh * .3, ew * .13, eh * .22, 0) < 1
        put(hl.astype(np.float32), hexrgb('ffffff'))
        # Upper lash line: thick, slightly winged outward (the key read at distance).
        lid = (ell(cx, ez + eh * .55, ew * 1.12, eh * .42, tilt) < 1) & ~(ell(cx, ez + eh * .2, ew * 1.0, eh * .55, tilt) < 1)
        put(lid.astype(np.float32), hexrgb('231a1a'))
        wing = ell(cx + sgn * ew * 1.0, ez + eh * .5, ew * .32, eh * .16, -tilt * 3) < 1
        put(wing.astype(np.float32), hexrgb('231a1a'), .9 if spec.get('lashes') else .5)
        low = (ell(cx, ez - eh * .7, ew * .8, eh * .12, tilt) < 1)
        put(low.astype(np.float32), hexrgb('8a5a50'), .5)
        # Brow
        brow = ell(cx + sgn * ew * .1, ez + eh * 2.3 + spec.get('brow_up', 0), ew * 1.15, eh * spec.get('brow_w', .28), tilt * -1.6 + sgn * spec.get('brow_tilt', .1)) < 1
        put(brow.astype(np.float32), hexrgb(c['hair']) * .7)
    # Nose: soft shadow on one side + nostril hint; mouth: short line + lip tint.
    nose = ell(.008, spec['nose_z'], .007, .016, .3) < 1
    put(nose.astype(np.float32), hexrgb(c['skin_sh']), .7)
    nos = ell(0, spec['nose_z'] - .012, .012, .004, 0) < 1
    put(nos.astype(np.float32), hexrgb(c['skin_sh']) * .8, .6)
    mz = spec['mouth_z']
    mouth = ell(0, mz, spec['mouth_w'], .0032, 0) < 1
    put(mouth.astype(np.float32), hexrgb('7d3d36'))
    lip = ell(0, mz - .007, spec['mouth_w'] * .6, .004, 0) < 1
    put(lip.astype(np.float32), hexrgb(c['lip']), .35)
    small = out.reshape(fh, ss, fw, ss, 3).mean(axis=(1, 3))
    img[fy:fy + fh, fx:fx + fw] = small


# --------------------------------------------------------------------- mesh
class Part:
    def __init__(self, name, bone):
        self.name, self.bone = name, bone
        self.v, self.uv, self.f = [], [], []


class Body:
    def __init__(self, pal):
        self.pal = pal
        self.parts = []

    def part(self, name, bone):
        p = Part(name, bone)
        self.parts.append(p)
        return p


def frame_for(t, prev=None):
    ref = Vector((0, -1, 0)) if abs(t.y) < .8 else Vector((0, 0, 1))
    if prev is not None:
        ref = prev
    front = (ref - t * ref.dot(t))
    if front.length < 1e-4:
        front = Vector((0, 0, 1)) - t * t.z
    front.normalize()
    side = t.cross(front).normalized()
    return front, side


def loft(part, centers, rings, color, sides=12, shape=None, cap0=True, cap1=True, t_range=(0, 1), uv_fn=None, front_ref=None):
    """Sculpted loft: rings = [(width, depth_front, depth_back, (dside, dfront))]. Not a cylinder:
    per-ring asymmetric ellipses plus an optional radial shape(angle, ring_t) modulation."""
    pal = part_pal[0]
    centers = [Vector(c) for c in centers]
    n = len(centers)
    tangents = [(centers[min(j + 1, n - 1)] - centers[max(j - 1, 0)]).normalized() for j in range(n)]
    base = len(part.v)
    prev_front = front_ref
    ring_ids = []
    for j, (c, t, r) in enumerate(zip(centers, tangents, rings)):
        w, df, db = r[0], r[1], r[2]
        off = r[3] if len(r) > 3 else (0, 0)
        front, side = frame_for(t, prev_front)
        prev_front = front if front_ref is None else front_ref
        rt = j / max(1, n - 1)
        ids = []
        for i in range(sides):
            a = i * TAU / sides
            ca, sa = math.cos(a), math.sin(a)
            d = df if sa > 0 else db
            k = shape(a, rt) if shape else 1.0
            p = c + side * (off[0] + ca * w * k) + front * (off[1] + sa * d * k)
            part.v.append(tuple(p))
            tt = lerp(t_range[0], t_range[1], rt)
            part.uv.append(uv_fn(p, tt, a) if uv_fn else pal.uv(color, tt * .8 + .1 * (1 - sa), .5 + .4 * ca))
            ids.append(len(part.v) - 1)
        ring_ids.append(ids)
    for a_, b_ in zip(ring_ids, ring_ids[1:]):
        for i in range(sides):
            i2 = (i + 1) % sides
            part.f.append((a_[i], a_[i2], b_[i2], b_[i]))
    for cap, ids, c, t, r in [(cap0, ring_ids[0], centers[0], -tangents[0], rings[0]), (cap1, ring_ids[-1], centers[-1], tangents[-1], rings[-1])]:
        if not cap:
            continue
        # Rounded cap: a smaller inner ring then the apex.
        radius = min(r[0], max(r[1], r[2]))
        ring_c = [Vector(part.v[i]) for i in ids]
        mid = sum(ring_c, Vector()) / len(ring_c)
        inner = []
        for q in ring_c:
            p = mid + (q - mid) * .62 + t * radius * .45
            part.v.append(tuple(p))
            part.uv.append(part.uv[ids[0]])
            inner.append(len(part.v) - 1)
        apex = mid + t * radius * .62
        part.v.append(tuple(apex))
        part.uv.append(part.uv[ids[0]])
        ai = len(part.v) - 1
        for i in range(sides):
            i2 = (i + 1) % sides
            part.f.append((ids[i], inner[i], inner[i2], ids[i2]))
            part.f.append((inner[i], ai, inner[i2]))


part_pal = [None]


def blob(part, center, radii, color, rings=7, sides=10, shape=None, t=.3, uv_fn=None):
    c = Vector(center)
    cs, rs = [], []
    for j in range(rings):
        th = -math.pi / 2 + math.pi * (j + .5) / rings
        cs.append(c + Vector((0, 0, math.sin(th) * radii[2])))
        rr = math.cos(th)
        rs.append((radii[0] * rr, radii[1] * rr, radii[1] * rr))
    loft(part, cs, rs, color, sides, shape, True, True, (t, t + .2), uv_fn)


def bezier(p0, p1, p2, n):
    p0, p1, p2 = Vector(p0), Vector(p1), Vector(p2)
    return [(1 - u) ** 2 * p0 + 2 * (1 - u) * u * p1 + u * u * p2 for u in [i / (n - 1) for i in range(n)]]


def lock(part, root, mid, tip, width, depth, color, n=5, sides=6, twist_front=None):
    """Tapered, flattened hair lock (big readable clump)."""
    pts = bezier(root, mid, tip, n)
    rings = [(width * (1 - .92 * (j / (n - 1)) ** 1.2), depth * (1 - .9 * (j / (n - 1))), depth * (1 - .9 * (j / (n - 1)))) for j in range(n)]
    loft(part, pts, rings, color, sides, None, True, True, (.15, .85), front_ref=twist_front)


def panel(body, name, bone, angle, radius, top_z, length, w_top, w_bot, color, trim, flare=.12, thick=.016):
    """Hanging cloth panel around the waist at `angle` (0 = front, -Y), with a hem trim."""
    d = Vector((math.sin(angle), -math.cos(angle), 0))
    top = Vector((0, 0, top_z)) + d * radius
    bottom = top + d * flare + Vector((0, 0, -length))
    pts = [top.lerp(bottom, f) + d * (flare * .4 * math.sin(math.pi * f)) for f in (0, .35, .7, 1.0)]
    widths = [w_top, lerp(w_top, w_bot, .4), lerp(w_top, w_bot, .75), w_bot]
    part = body.part(name, bone)
    loft(part, pts, [(w, thick, thick) for w in widths], color, 8, None, False, False, front_ref=d)
    hem = body.part(name + 'Hem', bone)
    loft(hem, [bottom + Vector((0, 0, .035)) + d * .003, bottom - Vector((0, 0, .005)) + d * .004], [(w_bot * 1.01, thick * 1.5, thick * 1.5)] * 2, trim, 8, None, True, True, front_ref=d)


# ------------------------------------------------------------------ anatomy
def build_body(hero, L, pal):
    body = Body(pal)
    part_pal[0] = pal
    cfg = HEROES[hero]
    s = cfg['scale']
    ch, hp = cfg['chest'], cfg['hips']
    C = pal.colors
    # ---- head (painted face via planar projection)
    hh = L['top'] - L['chin']
    hw = .128 * cfg['head'] * s
    face = dict(w=.17 * s, ztop=L['top'] + .02, zbot=L['chin'] - .03)

    def head_uv(p, t, a):
        u = (p[0] + face['w']) / (2 * face['w'])
        v = (face['ztop'] - p[2]) / (face['ztop'] - face['zbot'])
        x = (FACE[0] + max(0, min(1, u)) * FACE[2]) / ATLAS
        y = (FACE[1] + max(0, min(1, v)) * FACE[3]) / ATLAS
        return (x, 1 - y)
    head = body.part('Head', 'head')
    prof = [(0, .30, .26, .22, -.06), (.07, .52, .46, .42, -.045), (.2, .80, .62, .64, -.025), (.36, .94, .72, .84, -.012),
            (.5, 1.0, .74, .97, 0), (.64, 1.02, .72, 1.04, 0), (.8, .95, .62, 1.0, .005), (.93, .66, .42, .74, .01)]
    nose_f = .43
    cs, rs = [], []
    for f, wx, df, db, fo in prof:
        cs.append((0, -fo * s - .01 * s, L['chin'] + f * hh))
        rs.append((hw * wx, hw * df, hw * db))

    def head_shape(a, rt):
        bump = .2 * math.exp(-((a - math.pi / 2) / .2) ** 2) * math.exp(-((rt - nose_f / .93) / .07) ** 2)
        cheek = -.05 * math.exp(-((abs(math.cos(a)) - .7) / .2) ** 2) * math.exp(-((rt - .3) / .12) ** 2)
        return 1 + bump + cheek
    loft(head, cs, rs, 'skin', 20, head_shape, True, True, uv_fn=head_uv)
    eye_z = L['chin'] + .5 * hh
    spec = dict(w=face['w'], ztop=face['ztop'], zbot=face['zbot'], eye_x=.047 * s, eye_z=eye_z, eye_w=.024 * s, eye_h=.0165 * s,
                iris=cfg['eye'], nose_z=L['chin'] + .33 * hh, mouth_z=L['chin'] + .19 * hh, mouth_w=.018 * s, tilt=.1)
    if hero == 'lyra':
        spec.update(lashes=True, tilt=.16, brow_w=.2, brow_tilt=.18, brow_up=.004, mouth_w=.015)
    if hero == 'nira':
        spec.update(lashes=True, eye_w=.026 * s, eye_h=.019 * s, tilt=.05, brow_w=.22, brow_tilt=-.02, mouth_w=.016)
    if hero == 'kael':
        spec.update(brow_w=.34, brow_tilt=.2, eye_h=.015)
    for sgn in (-1, 1):  # ears
        ear = body.part('Ear', 'head')
        blob(ear, (sgn * hw * .98, .01, eye_z - .012), (.016, .03, .038), 'skin', 5, 8)
    # ---- neck
    neck = body.part('Neck', 'neck')
    loft(neck, [(0, .005, L['shoulder_z'] + .01), (0, .008, L['chin'] + .03)], [(.058 * s * (1.15 if hero == 'kael' else 1), .052 * s, .056 * s), (.052 * s, .046 * s, .052 * s)], 'skin', 10, None, False, True)
    # ---- torso (spine), V-taper for Kael, softer for Lyra/Nira
    torso = body.part('Torso', 'spine')
    w0 = .158 * s * hp
    rows = [(L['waist'] - .03, w0 * .92, .1, .095), (L['waist'] + .06, w0 * .9, .105, .098), (L['waist'] + .17 * s, .19 * s * ch + .02, .125 * s, .1 * s),
            (L['waist'] + .27 * s, .215 * s * ch + .015, .125 * s, .105 * s), (L['shoulder_z'] + .015, .2 * s * ch, .1 * s, .095 * s), (L['neck'] + .005, .085 * s, .06 * s, .065 * s)]
    tunic = 'tunic'

    def torso_shape(a, rt):
        pec = .06 * math.exp(-((a - math.pi / 2) / .5) ** 2) * math.exp(-((rt - .55) / .2) ** 2) * (1 if hero == 'kael' else 1.4)
        return 1 + pec
    loft(torso, [(0, 0, r[0]) for r in rows], [(r[1], r[2], r[3]) for r in rows], tunic, 14, torso_shape, True, True)
    # ---- pelvis / hips
    pel = body.part('Pelvis', 'pelvis')
    prow = [(L['hip'] - .07 * s, .12 * s * hp, .09, .1), (L['hip'] + .02, .165 * s * hp, .105, .115), (L['waist'] + .02, .155 * s * hp, .1, .1)]
    loft(pel, [(0, 0, r[0]) for r in prow], [(r[1], r[2], r[3]) for r in prow], 'trousers', 14, None, True, False)
    belt = body.part('Belt', 'pelvis')
    loft(belt, [(0, 0, L['waist'] - .045), (0, 0, L['waist'] + .025)], [(.163 * s * hp, .112, .108), (.16 * s * hp, .11, .106)], 'leather', 14, None, False, False)
    buckle = body.part('Buckle', 'pelvis')
    blob(buckle, (0, -.115 * hp, L['waist'] - .01), (.035, .012, .028), 'gold', 4, 8)
    # ---- arms
    for side, sg in (('L', 1), ('R', -1)):
        sh = Vector((sg * L['sx'], 0, L['shoulder_z']))
        el = Vector((sg * L['elbow'].x, L['elbow'].y, L['elbow'].z))
        wr = Vector((sg * L['wrist'].x, L['wrist'].y, L['wrist'].z))
        tip = Vector((sg * L['hand_tip'].x, L['hand_tip'].y, L['hand_tip'].z))
        ua = body.part('UpperArm' + side, 'upper_arm.' + side)
        arm_w = (1.15 if hero == 'kael' else .9) * s
        axis = (el - sh)
        pts = [sh + axis * f for f in (-.05, .15, .45, .8, 1.0)]
        sleeve = 'tunic_hi' if hero == 'kael' else 'tunic'
        loft(ua, pts, [(.06 * arm_w, .062 * arm_w, .06 * arm_w), (.062 * arm_w, .066 * arm_w, .062 * arm_w), (.056 * arm_w, .058 * arm_w, .056 * arm_w),
                       (.047 * arm_w, .049 * arm_w, .047 * arm_w), (.045 * arm_w, .046 * arm_w, .045 * arm_w)], sleeve, 10)
        fa = body.part('Forearm' + side, 'forearm.' + side)
        axis = wr - el
        pts = [el + axis * f for f in (-.04, .2, .55, .9, 1.02)]
        loft(fa, pts, [(.044 * arm_w, .044 * arm_w, .044 * arm_w), (.05 * arm_w, .05 * arm_w, .047 * arm_w), (.044 * arm_w, .041 * arm_w, .04 * arm_w),
                       (.036 * arm_w, .033 * arm_w, .033 * arm_w), (.035 * arm_w, .032 * arm_w, .032 * arm_w)], sleeve, 10)
        # Bracer / cuff: big readable shape over the lower forearm.
        cuff = body.part('Cuff' + side, 'forearm.' + side)
        cuff_col = {'kael': 'metal', 'lyra': 'trim', 'nira': 'leather'}[hero]
        pts = [el + axis * f for f in (.42, .7, .98)]
        if hero == 'lyra':  # bell sleeve flaring at the wrist
            loft(cuff, [el + axis * f for f in (.3, .7, 1.0, 1.08)], [(.05, .05, .05), (.075, .075, .075), (.11, .11, .11), (.105, .105, .105)], 'tunic', 12, None, False, False)
            trim_ring = body.part('SleeveTrim' + side, 'forearm.' + side)
            loft(trim_ring, [el + axis * 1.0, el + axis * 1.09], [(.113, .113, .113), (.108, .108, .108)], 'trim', 12, None, False, False)
        else:
            loft(cuff, pts, [(.052 * arm_w, .05 * arm_w, .05 * arm_w), (.05 * arm_w, .048 * arm_w, .048 * arm_w), (.047 * arm_w, .045 * arm_w, .045 * arm_w)], cuff_col, 10)
        hand(body, side, sg, wr, tip, hero, s)
    # ---- shoulders: the big silhouette read
    if hero == 'kael':
        pad = body.part('PauldronL', 'upper_arm.L')
        c = Vector((L['sx'] + .01, 0, L['shoulder_z'] + .015))
        for k, (dz, dx, r) in enumerate([(.0, 0, 1.0), (-.055, .02, .92), (-.105, .035, .8)]):
            plate = body.part('PauldronL%d' % k, 'upper_arm.L')
            blob(plate, c + Vector((dx, 0, dz)), (.095 * r, .092 * r, .07 * r), 'metal' if k == 0 else 'metal_dk', 6, 12)
        rim = body.part('PauldronRim', 'upper_arm.L')
        loft(rim, [c + Vector((-.06, 0, .0)), c + Vector((.1, 0, -.02))], [(.02, .1, .1), (.02, .085, .085)], 'gold', 10)
        strap = body.part('Strap', 'spine')
        pts = [(L['sx'] * .7, -.12, L['shoulder_z'] - .01), (0, -.135, L['waist'] + .2), (-L['sx'] * .65, -.115, L['waist'] + .03)]
        loft(strap, bezier(*pts, 6), [(.02, .012, .012)] * 6, 'leather', 6, front_ref=Vector((0, -1, 0)))
        padr = body.part('ShoulderR', 'upper_arm.R')
        blob(padr, (-L['sx'] - .02, 0, L['shoulder_z'] + .005), (.075, .075, .045), 'leather', 5, 10)
        collar = body.part('Collar', 'spine')
        loft(collar, [(0, .005, L['neck'] - .03), (0, .015, L['neck'] + .04)], [(.11, .085, .08), (.1, .075, .085)], 'tunic_hi', 14, None, False, False)
        # Long coat skirt: four panels, open at the front so the legs stride through.
        length = L['waist'] - L['knee'] - .02
        for name, ang, w0, w1 in (('CoatFL', .42, .07, .1), ('CoatFR', -.42, .07, .1), ('CoatBL', 2.45, .1, .14), ('CoatBR', -2.45, .1, .14), ('CoatB', math.pi, .08, .12)):
            panel(body, name, 'pelvis', ang, .15, L['waist'] - .02, length * (.92 if 'F' in name[-2:] else 1.0), w0, w1, 'tunic', 'tunic_hi', .1)
        vneck = body.part('Placket', 'spine')
        loft(vneck, [(0, -.118, L['waist'] + .05), (0, -.128, L['shoulder_z'] - .05), (0, -.098, L['neck'] - .01)], [(.025, .008, .008), (.03, .008, .008), (.035, .008, .008)], 'under', 6, None, True, True, front_ref=Vector((0, -1, 0)))
    elif hero == 'lyra':
        # Tall collared capelet: the signature silhouette.
        cap = body.part('Capelet', 'spine')
        loft(cap, [(0, .0, L['shoulder_z'] - .17), (0, .0, L['shoulder_z'] - .05), (0, .005, L['shoulder_z'] + .03), (0, .02, L['neck'] + .035), (0, .04, L['neck'] + .085)],
             [(.27, .17, .17), (.25, .155, .15), (.18, .12, .12), (.095, .08, .085), (.115, .085, .1)], 'cape', 16,
             shape=lambda a, rt: 1 + .08 * math.sin(a * 6) * (1 - rt) - (.35 if (math.sin(a) > .75 and rt > .5) else 0), cap0=False, cap1=False)
        cap_trim = body.part('CapeletTrim', 'spine')
        loft(cap_trim, [(0, 0, L['shoulder_z'] - .175), (0, 0, L['shoulder_z'] - .14)], [(.276, .176, .176), (.268, .17, .17)], 'trim', 16,
             shape=lambda a, rt: 1 + .08 * math.sin(a * 6), cap0=False, cap1=False)
        gem = body.part('Brooch', 'spine')
        blob(gem, (0, -.13, L['shoulder_z'] - .06), (.022, .014, .026), 'blade', 4, 8)
        # Open coat-dress: back panel + two front panels, legs walk through the opening.
        # Open coat-dress: violet side/back panels, light inner front panel, cream hems.
        for name, ang, w0, w1, ln, col in (('SkirtB', math.pi, .14, .24, .8, 'cape'), ('SkirtBL', 2.2, .1, .17, .76, 'tunic'), ('SkirtBR', -2.2, .1, .17, .76, 'tunic'),
                                            ('SkirtL', 1.25, .08, .13, .66, 'tunic'), ('SkirtR', -1.25, .08, .13, .66, 'tunic'), ('SkirtF', 0, .07, .1, .42, 'tunic_hi')):
            panel(body, name, 'pelvis', ang, .15, L['waist'] - .02, ln * s, w0, w1, col, 'trim', .14 if ang else .05)
        for name, z in (('Sash', L['waist'] - .01),):
            sash = body.part(name, 'pelvis')
            loft(sash, [(0, 0, z - .03), (0, 0, z + .03)], [(.168, .117, .113)] * 2, 'trim', 14, None, False, False)
    else:  # nira
        hood = body.part('Hood', 'spine')
        loft(hood, [(0, .1, L['shoulder_z'] - .02), (0, .14, L['neck'] + .02), (0, .155, L['neck'] + .1), (0, .14, L['neck'] + .16)],
             [(.2, .06, .08), (.16, .07, .09), (.13, .06, .08), (.08, .04, .05)], 'cape', 12, None, False, True)
        mantle = body.part('Mantle', 'spine')
        loft(mantle, [(0, .0, L['shoulder_z'] - .14), (0, .0, L['shoulder_z'] - .04), (0, .005, L['shoulder_z'] + .03), (0, .01, L['neck'] + .02)],
             [(.25, .155, .16), (.24, .145, .15), (.18, .115, .12), (.105, .08, .09)], 'cape', 16,
             shape=lambda a, rt: 1 + .06 * math.cos(a * 5) * (1 - rt), cap0=False, cap1=False)
        mtrim = body.part('MantleTrim', 'spine')
        loft(mtrim, [(0, 0, L['shoulder_z'] - .145), (0, 0, L['shoulder_z'] - .115)], [(.256, .16, .165), (.25, .155, .16)], 'trim', 16,
             shape=lambda a, rt: 1 + .06 * math.cos(a * 5), cap0=False, cap1=False)
        leaf = body.part('LeafPin', 'spine')
        blob(leaf, (.07, -.145, L['shoulder_z'] - .05), (.025, .012, .035), 'gold', 4, 8)
        tunic_skirt = body.part('TunicSkirt', 'pelvis')
        loft(tunic_skirt, [(0, 0, L['waist'] - .03), (0, .005, L['hip'] - .04), (0, .01, L['hip'] - .17)], [(.17, .12, .12), (.2, .145, .14), (.215, .16, .155)], 'tunic', 16,
             shape=lambda a, rt: 1 + .05 * math.sin(a * 7) * rt, cap0=False, cap1=False)
        hem = body.part('TunicHem', 'pelvis')
        loft(hem, [(0, .01, L['hip'] - .2), (0, .01, L['hip'] - .165)], [(.222, .165, .16), (.217, .162, .157)], 'under', 16,
             shape=lambda a, rt: 1 + .05 * math.sin(a * 7), cap0=False, cap1=False)
        for k, x in enumerate((-.12, .13)):
            pouch = body.part('Pouch%d' % k, 'pelvis')
            blob(pouch, (x, -.1, L['waist'] - .07), (.04, .03, .045), 'leather', 5, 8)
    # ---- legs
    for side, sg in (('L', 1), ('R', -1)):
        hipj = Vector((sg * L['hx'], 0, L['hip']))
        knee = Vector((sg * (L['hx'] + .008), -.012, L['knee']))
        ank = Vector((sg * (L['hx'] + .01), .01, L['ankle']))
        th = body.part('Thigh' + side, 'thigh.' + side)
        lw = (1.05 if hero == 'kael' else .95) * s * (1.05 if hero == 'nira' else 1)
        axis = knee - hipj
        loft(th, [hipj + axis * f for f in (-.08, .15, .5, .85, 1.03)],
             [(.088 * lw, .09 * lw, .09 * lw), (.085 * lw, .088 * lw, .085 * lw), (.074 * lw, .076 * lw, .07 * lw), (.06 * lw, .062 * lw, .058 * lw), (.056 * lw, .058 * lw, .055 * lw)],
             'trousers', 12)
        cf = body.part('Calf' + side, 'calf.' + side)
        axis = ank - knee
        loft(cf, [knee + axis * f for f in (-.04, .2, .45, .8, 1.0)],
             [(.055 * lw, .057 * lw, .056 * lw), (.058 * lw, .056 * lw, .07 * lw), (.052 * lw, .05 * lw, .06 * lw), (.04 * lw, .04 * lw, .043 * lw), (.038 * lw, .038 * lw, .04 * lw)],
             'trousers', 12)
        # Boots: chunky shaft + big foot (the classic heavy-boot read).
        boot = body.part('BootShaft' + side, 'calf.' + side)
        top_f = {'kael': .25, 'lyra': .12, 'nira': .4}[hero]
        loft(boot, [knee + axis * f for f in (top_f, top_f + .06, .7, 1.02)],
             [(.07 * lw, .07 * lw, .074 * lw), (.066 * lw, .066 * lw, .072 * lw), (.055 * lw, .056 * lw, .058 * lw), (.054 * lw, .056 * lw, .056 * lw)], 'boots', 12, None, False, False)
        if hero == 'kael':
            kg = body.part('KneeGuard' + side, 'calf.' + side)
            blob(kg, knee + Vector((0, -.05, -.03)), (.048, .025, .055), 'metal_dk', 5, 10)
        foot = body.part('Foot' + side, 'foot.' + side)
        fy = ank.y
        loft(foot, [(ank.x, fy + .055, .05), (ank.x, fy, .065), (ank.x, fy - .1, .055), (ank.x, fy - .2 * s, .042), (ank.x, fy - .245 * s, .035)],
             [(.058, .05, .05), (.064, .06, .06), (.066, .045, .045), (.058, .036, .036), (.045, .028, .028)], 'boots', 12,
             shape=None, front_ref=Vector((0, 0, 1)))
        sole = body.part('Sole' + side, 'foot.' + side)
        loft(sole, [(ank.x, fy + .065, .016), (ank.x, fy - .25 * s, .016)], [(.064, .016, .016), (.05, .014, .014)], 'leather_dk', 10, front_ref=Vector((0, 0, 1)))
    hair(body, hero, L, hw, s)
    return body


def hand(body, side, sg, wr, tip, hero, s):
    """Chunky mitten fist with a thumb: recognisable at battle distance."""
    hp = body.part('Hand' + side, 'hand.' + side)
    axis = (tip - wr)
    glove = {'kael': 'leather', 'lyra': 'skin', 'nira': 'leather'}[hero]
    k = (1.1 if hero == 'kael' else .95) * s
    loft(hp, [wr + axis * f for f in (-.05, .3, .65, .95)], [(.034 * k, .028 * k, .028 * k), (.044 * k, .03 * k, .034 * k), (.046 * k, .036 * k, .04 * k), (.04 * k, .04 * k, .032 * k)],
         glove, 10, shape=lambda a, rt: 1 + .12 * math.sin(a) * rt)
    th = body.part('Thumb' + side, 'hand.' + side)
    base = wr + axis * .35 + Vector((-sg * .028 * k, -.025 * k, 0))
    loft(th, [base, base + Vector((-sg * .012, -.03, -.04)) * k, base + Vector((-sg * .008, -.045, -.07)) * k], [(.016 * k, .015 * k, .015 * k), (.014 * k, .013 * k, .013 * k), (.011 * k, .011 * k, .011 * k)], glove, 8)


def hair(body, hero, L, hw, s):
    """Hair = a skull cap plus big locks rooted on the cap by angle.
    theta: 0 = front (-Y), +90deg = character's left (+X). phi: 0 = eye level, 90 = crown.
    The face window (|theta| < 55deg, below the brow) is never crossed by a lock."""
    top, chin = L['top'], L['chin']
    hh = top - chin
    eye_z = chin + .5 * hh
    brow_z = eye_z + .075 * s
    cap_c = Vector((0, .012 * s, chin + .62 * hh))
    rx, ry, rz = hw * 1.08, hw * 1.13, hh * .47
    capp = body.part('HairCap', 'head')
    blob(capp, cap_c, (rx, ry, rz), 'hair', 8, 16,
         shape=lambda a, rt: 1 - (.2 if (math.sin(a) > .5 and rt < .5) else 0))
    p = body.part('Locks', 'head')
    D = math.radians

    def scalp(theta, phi, lift=1.0):
        th, ph = D(theta), D(phi)
        n = Vector((math.sin(th) * math.cos(ph), -math.cos(th) * math.cos(ph), math.sin(ph)))
        q = cap_c + Vector((n.x * rx, n.y * ry, n.z * rz)) * lift
        return q, n

    def from_scalp(theta, phi, out, down, side=0.0, back=0.0, width=.05, depth=.026, col='hair', bend=.5):
        root, n = scalp(theta, phi, .9)
        th = D(theta)
        side_v = Vector((math.cos(th), math.sin(th), 0))
        back_v = Vector((0, 1, 0))
        tip = root + n * out + Vector((0, 0, -down)) + side_v * side + back_v * back
        mid = root + n * out * (1 + bend) * .6 + (tip - root) * .35 + Vector((0, 0, .02))
        lock(p, root, mid, tip, width * s, depth * s, col, 5, 6)

    if hero == 'kael':
        # Side-parted fringe swept to his left, layered sides to the jaw,
        # pointed locks at the back and two crown cowlicks: windswept hero.
        for i, th in enumerate((-38, -18, 2, 22, 40)):
            root, n = scalp(th, 68, .92)
            end_z = brow_z + .01 + .015 * (i % 2)
            tip = Vector((root.x + .07 * s + .02 * i * s, root.y - .05 * s, end_z))
            mid = (root + tip) * .5 + Vector((.01, -.05 * s, .035))
            lock(p, root, mid, tip, .056 * s, .026 * s, 'hair_hi' if i % 2 else 'hair', 5, 6)
        for sg in (-1, 1):
            for th, ph, down in ((62, 45, .2), (85, 35, .2), (105, 30, .17)):
                from_scalp(sg * th, ph, .05, down * s, side=sg * .01, back=.015, width=.05, col='hair')
        for th in (135, 160, 180, 200, 225):
            from_scalp(th, 30, .1, .12 * s, back=.1 * s, width=.058, depth=.03)
        for th in (150, 210):
            from_scalp(th, 62, .09, .03 * s, back=.14 * s, width=.055, col='hair_hi')
        for th in (-70, 70, 180):
            from_scalp(th, 78, .07, .02 * s, back=.1 * s, width=.055)
    elif hero == 'lyra':
        # Long straight mass down the back, front locks framing the face,
        # bangs swept to one side ending above the eyes.
        for th in range(105, 260, 17):
            root, n = scalp(th, 35, .92)
            out = Vector((n.x, n.y, 0)).normalized()
            tip = root + out * .06 * s + Vector((0, .05 * s, -.95 * s - .1 * math.cos(D(th - 180)) * s))
            mid = root + out * .07 * s + Vector((0, .03, -.3 * s))
            lock(p, root, mid, tip, .07 * s, .03 * s, 'hair', 6, 6)
        for sg in (-1, 1):
            root, n = scalp(sg * 72, 40, .95)
            tip = Vector((sg * (hw + .055) * 1.0, -.03 * s, chin - .32 * s))
            mid = Vector((sg * (hw + .04), -.01, chin + .02))
            lock(p, root, mid, tip, .05 * s, .022 * s, 'hair_hi', 6, 6)
        for i, th in enumerate((-48, -25, -2, 20)):
            root, n = scalp(th, 72, .92)
            tip = Vector((root.x + .09 * s, root.y - .045 * s, brow_z + .005 + .02 * i))
            mid = (root + tip) * .5 + Vector((0, -.05 * s, .04))
            lock(p, root, mid, tip, .05 * s, .022 * s, 'hair_hi' if i % 2 else 'hair', 5, 6)
        pin = body.part('HairPin', 'head')
        q, n = scalp(70, 50, 1.0)
        blob(pin, q + n * .01, (.02, .012, .032), 'blade', 4, 8)
    else:
        # Rounded chin-length bob: locks fall around the head to the jaw and tuck
        # inward; a short straight fringe; one small braid on her left.
        for th in range(60, 301, 20):
            root, n = scalp(th, 40, .92)
            out = Vector((n.x, n.y, 0)).normalized()
            tip = root + out * .045 * s + Vector((0, 0, -(root.z - (chin + .02 * s))))
            mid = root + out * .07 * s + Vector((0, 0, -.06 * s))
            lock(p, root, mid, tip, .072 * s, .032 * s, 'hair', 5, 6)
        for i, th in enumerate(range(-40, 41, 16)):
            root, n = scalp(th, 70, .92)
            tip = Vector((root.x * 1.1, root.y - .05 * s, brow_z + .012 - .006 * (i % 2)))
            mid = (root + tip) * .5 + Vector((0, -.045 * s, .03))
            lock(p, root, mid, tip, .05 * s, .022 * s, 'hair_hi' if i % 2 else 'hair', 5, 6)
        br = body.part('Braid', 'head')
        q, n = scalp(92, 20, 1.0)
        for k in range(4):
            blob(br, q + Vector((.012, -.01, -.03 - k * .055 * s)), (.024, .022, .034), 'hair_hi' if k % 2 else 'hair', 5, 8)
        tie = body.part('BraidTie', 'head')
        blob(tie, q + Vector((.012, -.01, -.28 * s)), (.02, .02, .015), 'cape', 4, 8)


def weapon(hero, L, pal):
    part_pal[0] = pal
    w = Body(pal)
    sg = -1  # right hand (character's right is -X, facing -Y)
    wr = Vector((sg * L['wrist'].x, L['wrist'].y, L['wrist'].z))
    tip = Vector((sg * L['hand_tip'].x, L['hand_tip'].y, L['hand_tip'].z))
    grip_c = wr + (tip - wr) * .62
    if hero == 'kael':
        p = w.part('KaelSword', 'hand.R')
        # Rest: blade forward (-Y), slight upward angle. Original broad longsword.
        d = Vector((0, -1, .12)).normalized()
        g0 = grip_c - d * .11
        loft(p, [g0 - d * .03, g0, grip_c + d * .07], [(.02, .02, .02), (.019, .019, .019), (.019, .019, .019)], 'grip', 8)
        blob(w.part('Pommel', 'hand.R'), g0 - d * .045, (.03, .03, .03), 'gold', 5, 8)
        guard = w.part('Guard', 'hand.R')
        gc = grip_c + d * .085
        loft(guard, [gc + Vector((-.13, 0, -.02)), gc + Vector((-.05, 0, 0)), gc + Vector((.05, 0, 0)), gc + Vector((.13, 0, -.02))],
             [(.018, .022, .022), (.03, .03, .03), (.03, .03, .03), (.018, .022, .022)], 'metal', 8, front_ref=Vector((0, -1, 0)))
        blade = w.part('Blade', 'hand.R')
        b0 = gc + d * .02
        up = Vector((1, 0, 0))
        pts = [b0 + d * f for f in (0, .12, .55, .82, .95, 1.0)]
        widths = [.045, .052, .05, .042, .02, .004]
        loft(blade, pts, [(wd, .009, .009) for wd in widths], 'blade', 8, front_ref=Vector((0, 0, 1)),
             uv_fn=lambda q, t, a: pal.uv('blade_edge' if abs(math.cos(a)) > .9 else 'blade', t * .7, .5))
        fuller = w.part('Fuller', 'hand.R')
        loft(fuller, [b0 + d * .05, b0 + d * .6], [(.008, .0105, .0105), (.006, .0105, .0105)], 'metal_dk', 6, front_ref=Vector((0, 0, 1)))
    else:
        p = w.part('Focus', 'hand.R')
        d = Vector((0, -.12, 1)).normalized()  # staff upright
        length = 1.35 if hero == 'lyra' else 1.05
        bottom = grip_c - d * (.55 if hero == 'lyra' else .42)
        pts = [bottom + d * f * length for f in (0, .3, .7, 1.0)]
        loft(p, pts, [(.018, .018, .018), (.02, .02, .02), (.02, .02, .02), (.024, .024, .024)], 'grip', 8)
        top = pts[-1]
        crystal_col = 'blade'
        if hero == 'lyra':
            for sgn in (-1, 1):
                horn = w.part('Crescent', 'hand.R')
                loft(horn, bezier(top, top + Vector((sgn * .1, 0, .08)), top + Vector((sgn * .05, 0, .24)), 5), [(.016, .012, .012), (.015, .011, .011), (.013, .01, .01), (.01, .008, .008), (.006, .005, .005)], 'metal', 6)
            cr = w.part('Crystal', 'hand.R')
            loft(cr, [top + Vector((0, 0, .05)), top + Vector((0, 0, .13)), top + Vector((0, 0, .24))], [(.004, .004, .004), (.045, .035, .035), (.004, .004, .004)], crystal_col, 6, cap0=True, cap1=True)
        else:
            leaf = w.part('Leaf', 'hand.R')
            for sgn in (-1, 1):
                loft(leaf, bezier(top + Vector((0, 0, -.02)), top + Vector((sgn * .09, 0, .06)), top + Vector((sgn * .03, -.02, .17)), 5), [(.018, .008, .008)] * 4 + [(.004, .004, .004)], 'cape', 6)
            cr = w.part('Crystal', 'hand.R')
            blob(cr, top + Vector((0, -.01, .09)), (.035, .03, .05), crystal_col, 5, 8)
            ring = w.part('Band', 'hand.R')
            loft(ring, [top - d * .03, top + d * .01], [(.026, .026, .026)] * 2, 'gold', 8)
    return w


# ------------------------------------------------------------------- objects
def material(hero, image):
    mat = bpy.data.materials.new(hero.title() + 'PS1')
    mat.use_nodes = True
    node = mat.node_tree.nodes.get('Principled BSDF')
    node.inputs['Roughness'].default_value = .82
    node.inputs['Specular IOR Level'].default_value = .2
    tex = mat.node_tree.nodes.new('ShaderNodeTexImage')
    tex.image = image
    tex.interpolation = 'Linear'
    mat.node_tree.links.new(tex.outputs['Color'], node.inputs['Base Color'])
    return mat


def make_object(name, body, rig, mat, bone_names):
    verts, faces, uvs, groups = [], [], [], []
    for part in body.parts:
        base = len(verts)
        verts.extend(part.v)
        uvs.extend(part.uv)
        groups.extend([part.bone] * len(part.v))
        faces.extend([tuple(base + i for i in f) for f in part.f])
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    layer = mesh.uv_layers.new(name='UVMap')
    for loop in mesh.loops:
        layer.data[loop.index].uv = uvs[loop.vertex_index]
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = True
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    for b in bone_names:
        obj.vertex_groups.new(name=b)
    for i, g in enumerate(groups):
        obj.vertex_groups[g].add([i], 1.0, 'REPLACE')   # rigid: one bone per part
    obj.parent = rig
    mod = obj.modifiers.new('Armature', 'ARMATURE')
    mod.object = rig
    return obj


def rig_create(hero, L):
    data = bpy.data.armatures.new(hero.title() + 'PS1Skeleton')
    rig = bpy.data.objects.new(hero.title() + 'Rig', data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode='EDIT')
    d = {'root': ((0, 0, 0), (0, 0, .14), None), 'pelvis': ((0, 0, L['hip']), (0, 0, L['waist']), 'root'),
         'spine': ((0, 0, L['waist']), (0, 0, L['shoulder_z']), 'pelvis'), 'neck': ((0, 0, L['shoulder_z']), (0, 0, L['chin']), 'spine'),
         'head': ((0, 0, L['chin']), (0, 0, L['top']), 'neck')}
    for side, sg in (('L', 1), ('R', -1)):
        def m(v):
            return (sg * v.x, v.y, v.z)
        sh = Vector((L['sx'], 0, L['shoulder_z']))
        d.update({'upper_arm.' + side: (m(sh), m(L['elbow']), 'spine'), 'forearm.' + side: (m(L['elbow']), m(L['wrist']), 'upper_arm.' + side),
                  'hand.' + side: (m(L['wrist']), m(L['hand_tip']), 'forearm.' + side),
                  'thigh.' + side: ((sg * L['hx'], 0, L['hip']), (sg * (L['hx'] + .008), -.012, L['knee']), 'pelvis'),
                  'calf.' + side: ((sg * (L['hx'] + .008), -.012, L['knee']), (sg * (L['hx'] + .01), .01, L['ankle']), 'thigh.' + side),
                  'foot.' + side: ((sg * (L['hx'] + .01), .01, L['ankle']), (sg * (L['hx'] + .01), -.17, .04), 'calf.' + side)})
    for name, (h, t, parent) in d.items():
        b = data.edit_bones.new(name)
        b.head, b.tail = h, t
        if parent:
            b.parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT')
    return rig


# ----------------------------------------------------------------- animation
def rotate(rig, poses):
    for name, angles in poses.items():
        rig.pose.bones[name].rotation_quaternion = Euler(angles, 'XYZ').to_quaternion()


def offset(rig, name, delta):
    rig.pose.bones[name].location = rig.data.bones[name].matrix_local.to_3x3().inverted() @ Vector(delta)


def aim(rig, name, start, end):
    bone = rig.data.bones[name]
    q = (bone.tail_local - bone.head_local).normalized().rotation_difference((end - start).normalized())
    matrix = (q.to_matrix() @ bone.matrix_local.to_3x3()).to_4x4()
    matrix.translation = start
    rig.pose.bones[name].matrix = matrix
    bpy.context.view_layer.update()


def chain(rig, upper, lower, tip, target, bend, tip_rot=None):
    start = rig.pose.bones[upper].head.copy()
    a = rig.data.bones[upper].length
    b = rig.data.bones[lower].length
    delta = target - start
    dist = min(delta.length, a + b - .002)
    axis = delta.normalized()
    target = start + axis * dist
    along = (a * a - b * b + dist * dist) / (2 * dist)
    pole = (bend - axis * axis.dot(bend)).normalized()
    middle = start + axis * along + pole * math.sqrt(max(0, a * a - along * along))
    aim(rig, upper, start, middle)
    aim(rig, lower, middle, target)
    rest = rig.data.bones[tip].matrix_local.to_3x3()
    rot = (tip_rot.to_matrix() if tip_rot is not None else Matrix.Identity(3))
    m = (rot @ rest).to_4x4()
    m.translation = target
    rig.pose.bones[tip].matrix = m
    bpy.context.view_layer.update()


def qe(x=0, y=0, z=0):
    return Euler((x, y, z), 'XYZ').to_quaternion()


def ease(t):
    return smooth(t)


def key_blend(keys, t):
    """keys: list of (time, value) with values Vector/float/Quaternion; smooth interpolation."""
    for (t0, v0), (t1, v1) in zip(keys, keys[1:]):
        if t <= t1:
            u = ease((t - t0) / max(1e-6, t1 - t0))
            if isinstance(v0, Quaternion):
                return v0.slerp(v1, u)
            return v0 + (v1 - v0) * u
    return keys[-1][1]


def pose(rig, hero, L, clip, t):
    for b in rig.pose.bones:
        b.rotation_mode = 'QUATERNION'
        b.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    s = HEROES[hero]['scale']
    sh = L['shoulder_z']
    rest_hand = {sd: rig.data.bones['hand.' + sd].head_local.copy() for sd in 'LR'}
    feet = {sd: rig.data.bones['foot.' + sd].head_local.copy() for sd in 'LR'}
    # Battle stance (FF-style ready pose): staggered feet, bent knees, weapon forward.
    stance = {'kael': .07, 'lyra': .035, 'nira': .045}[hero]
    breath = math.sin(t * TAU) if clip == 'Idle' else 0.0
    pelvis_drop = stance + .008 * breath
    spine = qe(.06 + .01 * breath, 0, -.08 if hero == 'kael' else -.04)
    head = qe(-.04, 0, .06 if hero == 'kael' else .03)
    foot_t = {'L': feet['L'] + Vector((.03, -.1 * s, 0)), 'R': feet['R'] + Vector((-.02, .12 * s, 0))}
    if hero == 'kael':
        hand_t = {'R': Vector((-.2, -.3, sh - .43)), 'L': Vector((.22, -.12, sh - .5))}
        hand_r = {'R': qe(.25, 0, -.5), 'L': qe(0, 0, 0)}
    elif hero == 'lyra':
        hand_t = {'R': Vector((-.24, -.18, sh - .42)), 'L': Vector((.22, -.16, sh - .4))}
        hand_r = {'R': qe(0, 0, 0), 'L': qe(-.5, 0, 0)}
    else:
        hand_t = {'R': Vector((-.22, -.16, sh - .45)), 'L': Vector((.18, -.2, sh - .35))}
        hand_r = {'R': qe(0, 0, 0), 'L': qe(-.4, 0, .3)}
    root_rot = Quaternion()
    root_off = Vector()
    if clip == 'Idle':
        hand_t = {k: v + Vector((0, 0, .008 * breath)) for k, v in hand_t.items()}
    elif clip == 'Walk':
        ph = t * TAU
        pelvis_drop = .035 - .02 * abs(math.cos(ph))
        spine = qe(.05, .03 * math.sin(ph), 0)
        head = qe(-.02, -.02 * math.sin(ph), 0)
        stride = HEROES[hero].get('stride', .26) * s
        for sd, shift in (('L', 0), ('R', .5)):
            q = (t + shift) % 1
            if q < .5:
                y = -stride + 2 * stride * (q / .5)   # planted: moves back at ground speed
                lift = 0
            else:
                u = (q - .5) / .5
                y = stride - 2 * stride * ease(u)
                lift = .1 * math.sin(math.pi * u) * s
            foot_t[sd] = feet[sd] + Vector((0, y, lift))
        swing = math.cos(ph)
        hand_t['L'] = rest_hand['L'] + Vector((-.03, .16 * swing, .05 + .03 * abs(swing)))
        hand_t['R'] = hand_t['R'] + Vector((0, -.06 * swing, .02))
    elif clip == 'Attack':
        if hero == 'kael':
            hand_t['R'] = key_blend([(0, hand_t['R']), (.32, Vector((-.12, .05, sh + .28))), (.55, Vector((.05, -.48, sh - .3))), (.72, Vector((.08, -.46, sh - .36))), (1, hand_t['R'])], t)
            hand_r['R'] = key_blend([(0, hand_r['R']), (.32, qe(-2.4, 0, -.2)), (.55, qe(.05, 0, -.45)), (.72, qe(.12, 0, -.5)), (1, hand_r['R'])], t)
            spine = key_blend([(0, spine), (.32, qe(-.08, 0, -.5)), (.55, qe(.16, 0, .35)), (.75, qe(.16, 0, .35)), (1, spine)], t)
            foot_t['R'] = key_blend([(0, foot_t['R']), (.4, foot_t['R']), (.55, feet['R'] + Vector((0, -.2, 0))), (.8, feet['R'] + Vector((0, -.2, 0))), (1, foot_t['R'])], t)
            pelvis_drop = key_blend([(0, stance), (.32, stance - .02), (.55, stance + .1), (.8, stance + .1), (1, stance)], t)
        else:
            reach = Vector((-.12, -.48, sh - .2)) if hero == 'lyra' else Vector((-.08, -.42, sh - .12))
            hand_t['R'] = key_blend([(0, hand_t['R']), (.3, hand_t['R'] + Vector((0, .12, .12))), (.55, reach), (.75, reach), (1, hand_t['R'])], t)
            hand_r['R'] = key_blend([(0, hand_r['R']), (.3, qe(-.4, 0, 0)), (.55, qe(1.1, 0, 0)), (.75, qe(1.1, 0, 0)), (1, hand_r['R'])], t)
            spine = key_blend([(0, spine), (.3, qe(-.05, 0, -.25)), (.55, qe(.22, 0, .25)), (.75, qe(.22, 0, .25)), (1, spine)], t)
            pelvis_drop = key_blend([(0, stance), (.55, stance + .05), (.75, stance + .05), (1, stance)], t)
    elif clip == 'Hurt':
        a = math.sin(math.pi * t) ** 2
        spine = spine.slerp(qe(-.3, .1, .1), a)
        head = head.slerp(qe(-.25, 0, -.15), a)
        root_off = Vector((0, .07 * a, 0))
        hand_t = {k: v + Vector((0, .08 * a, .06 * a)) for k, v in hand_t.items()}
    elif clip == 'Defend':
        a = ease(t)
        if hero == 'kael':
            hand_t['R'] = hand_t['R'].lerp(Vector((-.06, -.3, sh - .12)), a)
            hand_r['R'] = hand_r['R'].slerp(qe(-.2, 0, 1.45), a)
            hand_t['L'] = hand_t['L'].lerp(Vector((.12, -.28, sh - .2)), a)
        elif hero == 'lyra':
            hand_t['R'] = hand_t['R'].lerp(Vector((-.1, -.3, sh - .25)), a)
            hand_r['R'] = hand_r['R'].slerp(qe(0, -.9, 0), a)
            hand_t['L'] = hand_t['L'].lerp(Vector((.1, -.3, sh - .15)), a)
        else:
            hand_t['R'] = hand_t['R'].lerp(Vector((-.08, -.26, sh - .2)), a)
            hand_t['L'] = hand_t['L'].lerp(Vector((.06, -.24, sh - .05)), a)
            hand_r['R'] = hand_r['R'].slerp(qe(0, .7, 0), a)
        spine = spine.slerp(qe(.18, 0, 0), a)
        pelvis_drop = stance + .06 * a
    elif clip == 'KO':
        u = ease(t)
        k1 = ease(min(1, t / .45))
        k2 = ease(max(0, (t - .35) / .65))
        pelvis_drop = stance + .35 * k1
        spine = spine.slerp(qe(.5, 0, 0), k1)
        head = head.slerp(qe(.4, 0, .2), k1)
        root_rot = qe(-1.45 * k2, 0, .2 * k2)
        root_off = Vector((0, .25 * k2, 0))
        hand_t = {k: v.lerp(rest_hand[k] + Vector((0, -.05, -.05)), k1) for k, v in hand_t.items()}
    elif clip == 'Cast':  # Lyra: staff raised, open palm forward
        a = ease(min(1, t / .35)) * (1 - ease(max(0, (t - .75) / .25)))
        hand_t['R'] = hand_t['R'].lerp(Vector((-.2, -.12, sh + .32)), a)
        hand_r['R'] = hand_r['R'].slerp(qe(-.25, 0, 0), a)
        hand_t['L'] = hand_t['L'].lerp(Vector((.08, -.5, sh - .02)), a)
        hand_r['L'] = hand_r['L'].slerp(qe(-1.4, 0, 0), a)
        spine = spine.slerp(qe(-.06, 0, .15), a)
        head = head.slerp(qe(-.12, 0, 0), a)
    elif clip == 'Support':  # Nira: gather at chest, then open upward toward allies
        a1 = ease(min(1, t / .35))
        a2 = ease(max(0, min(1, (t - .4) / .3))) * (1 - ease(max(0, (t - .82) / .18)))
        a1 = a1 * (1 - ease(max(0, (t - .82) / .18)))
        chest = Vector((.0, -.2, sh - .12))
        hand_t['L'] = hand_t['L'].lerp(chest + Vector((.05, 0, 0)), a1).lerp(Vector((.2, -.34, sh + .22)), a2)
        hand_r['L'] = hand_r['L'].slerp(qe(-1.2, 0, .5), max(a1, a2))
        hand_t['R'] = hand_t['R'].lerp(Vector((-.16, -.25, sh + .05)), max(a1 * .5, a2))
        spine = spine.slerp(qe(-.08, 0, 0), a2)
        head = head.slerp(qe(-.15, 0, 0), a2)
    rig.pose.bones['root'].rotation_quaternion = root_rot
    rig.pose.bones['root'].location = root_off
    offset(rig, 'pelvis', (0, 0, -pelvis_drop))
    rig.pose.bones['spine'].rotation_quaternion = spine
    rig.pose.bones['head'].rotation_quaternion = head
    bpy.context.view_layer.update()
    rmat = rig.pose.bones['root'].matrix.to_3x3() @ rig.data.bones['root'].matrix_local.to_3x3().inverted()
    rpos = rig.pose.bones['root'].head - rig.data.bones['root'].head_local
    for sd, sg in (('L', 1), ('R', -1)):
        target = rmat @ foot_t[sd] + rpos
        chain(rig, 'thigh.' + sd, 'calf.' + sd, 'foot.' + sd, target, rmat @ Vector((0, -1, .1)), rmat.to_quaternion())
    for sd, sg in (('L', 1), ('R', -1)):
        # Hand targets are relative to the (possibly bent) chest.
        sp = rig.pose.bones['spine']
        smat = sp.matrix.to_3x3() @ rig.data.bones['spine'].matrix_local.to_3x3().inverted()
        anchor_rest = rig.data.bones['spine'].head_local
        target = sp.head + smat @ (hand_t[sd] - anchor_rest)
        rot = smat.to_quaternion() @ hand_r[sd]
        chain(rig, 'upper_arm.' + sd, 'forearm.' + sd, 'hand.' + sd, target, smat @ Vector((sg * .6, .5, -.3)), rot)


def min_z(objects):
    deps = bpy.context.evaluated_depsgraph_get()
    low = 100
    for obj in objects:
        ev = obj.evaluated_get(deps)
        mesh = ev.to_mesh()
        low = min(low, min((ev.matrix_world @ v.co).z for v in mesh.vertices))
        ev.to_mesh_clear()
    return low


def animate(rig, objects, hero, L):
    lengths = {'Idle': 2.4, 'Walk': .58, 'Attack': .8, 'Hurt': .4, 'Defend': .4, 'KO': 1.0}
    if hero == 'lyra':
        lengths['Cast'] = .9
    if hero == 'nira':
        lengths['Support'] = 1.0
    rig.animation_data_clear()
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)
    checks = {}
    body = objects[0]
    for clip, seconds in lengths.items():
        action = bpy.data.actions.new(clip)
        action.use_fake_user = True
        rig.animation_data_create()
        rig.animation_data.action = action
        count = max(2, round(seconds * 30))   # keys at 30 Hz, exported sampled
        minima = []
        for frame in range(count + 1):
            bpy.context.scene.frame_set(frame + 1)
            pose(rig, hero, L, clip, frame / count)
            z = min_z(objects)   # body AND weapon: a staff must not sink either
            if z < 0.0 or clip in ('KO',):
                m = rig.pose.bones['root'].matrix.copy()
                m.translation.z += 0.0 - z
                rig.pose.bones['root'].matrix = m
                bpy.context.view_layer.update()
            minima.append(min_z(objects))
            for bone in rig.pose.bones:
                for channel in ('location', 'rotation_quaternion', 'scale'):
                    bone.keyframe_insert(channel, frame=frame + 1, group=bone.name)
        checks[clip] = {'seconds': seconds, 'min_vertex_z': min(minima)}
    rig.animation_data.action = bpy.data.actions['Idle']
    bpy.context.scene.frame_set(1)
    return checks, lengths


def export(hero, rig, objects, out, checks, lengths):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in [rig] + objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    path = out / (hero + '.glb')
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=True, export_yup=True, export_skins=True,
                              export_def_bones=False, export_animations=True, export_animation_mode='ACTIONS', export_merge_animation='ACTION',
                              export_anim_single_armature=True, export_anim_slide_to_zero=True, export_force_sampling=True, export_frame_step=1)
    blob_ = path.read_bytes()
    n = struct.unpack_from('<I', blob_, 12)[0]
    g = json.loads(blob_[20:20 + n])
    prims = [p for m in g['meshes'] for p in m['primitives']]
    assert all('uri' not in b for b in g['buffers'] + g.get('images', []))
    deps = bpy.context.evaluated_depsgraph_get()
    zs = [(o.matrix_world @ v.co).z for o in objects[:1] for v in o.data.vertices]
    stride = HEROES[hero].get('stride', .26) * HEROES[hero]['scale']
    report = {
        'character': hero, 'art_revision': 'ps1-battle-experiment', 'blender': bpy.app.version_string,
        'method': 'Original rigid sculpted parts per bone, painted palette atlas and painted face; no third-party or existing character geometry',
        'triangles': sum(g['accessors'][p['indices']]['count'] // 3 for p in prims),
        'exported_vertices': sum(g['accessors'][p['attributes']['POSITION']]['count'] for p in prims),
        'author_vertices': sum(len(o.data.vertices) for o in objects), 'surfaces': len(prims), 'materials': len(g['materials']),
        'textures': len(g.get('images', [])), 'bones': len(rig.data.bones), 'animations': [a['name'] for a in g['animations']],
        'animation_checks': checks, 'glb_bytes': len(blob_), 'texture_size': [ATLAS, ATLAS], 'height': max(zs),
        'walk_reference_speed': 4 * stride / lengths['Walk'], 'locomotion_blend': .12, 'lunge_distance': 0.0,
        'presentation_durations': lengths, 'authored_sections': sum(len(o.data.polygons) for o in objects),
        'glb_sha256': sha(path), 'blend_sha256': sha(out / (hero + '.blend')), 'atlas_sha256': sha(out / (hero + '_atlas.png')),
        'build_script_sha256': sha(Path(__file__)), 'mobile_tested': False}
    (out / (hero + '_manifest.json')).write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print('PS1', json.dumps({k: report[k] for k in ('character', 'triangles', 'exported_vertices', 'glb_bytes', 'height', 'animations')}))


if not bpy.app.background:
    raise RuntimeError('Use a separate background Blender process')
args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
heroes = [args[args.index('--hero') + 1]] if '--hero' in args else ['kael', 'lyra', 'nira']
BONES = ['root', 'pelvis', 'spine', 'neck', 'head'] + [b + '.' + s for s in 'LR' for b in ('upper_arm', 'forearm', 'hand', 'thigh', 'calf', 'foot')]
for hero in heroes:
    out = ROOT / 'assets/characters' / hero / 'ps1'
    out.mkdir(parents=True, exist_ok=True)
    weapon_name = 'KaelSword' if hero == 'kael' else 'Focus'
    if '--export-only' in args:
        bpy.ops.wm.open_mainfile(filepath=str(out / (hero + '.blend')))
        report = json.loads((out / (hero + '_manifest.json')).read_text(encoding='utf-8'))
        checks, lengths = report['animation_checks'], report['presentation_durations']
        rig = bpy.data.objects[hero.title() + 'Rig']
        objects = [bpy.data.objects[hero.title() + 'Body'], bpy.data.objects[weapon_name]]
    else:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        L = landmarks(hero)
        pal = Palette(HEROES[hero]['colors'])
        rig = rig_create(hero, L)
        body = build_body(hero, L, pal)
        # Face spec must exist before painting: rebuild it from the same numbers.
        s = HEROES[hero]['scale']
        hh = L['top'] - L['chin']
        fspec = dict(w=.17 * s, ztop=L['top'] + .02, zbot=L['chin'] - .03, eye_x=.047 * s, eye_z=L['chin'] + .5 * hh, eye_w=.024 * s, eye_h=.0165 * s,
                     iris=HEROES[hero]['eye'], nose_z=L['chin'] + .33 * hh, mouth_z=L['chin'] + .19 * hh, mouth_w=.018 * s, tilt=.1)
        if hero == 'lyra':
            fspec.update(lashes=True, tilt=.16, eye_w=.026 * s, eye_h=.018 * s, brow_w=.2, brow_tilt=.18, brow_up=.004, mouth_w=.015)
        if hero == 'nira':
            fspec.update(lashes=True, eye_w=.026 * s, eye_h=.019 * s, tilt=.05, brow_w=.22, brow_tilt=-.02, mouth_w=.016)
        if hero == 'kael':
            fspec.update(brow_w=.34, brow_tilt=.2, eye_h=.015)
        image = paint_atlas(hero, pal, fspec, out)
        mat = material(hero, image)
        body_obj = make_object(hero.title() + 'Body', body, rig, mat, BONES)
        weapon_obj = make_object(weapon_name, weapon(hero, L, pal), rig, mat, BONES)
        objects = [body_obj, weapon_obj]
        bpy.context.scene.render.fps = 30
        checks, lengths = animate(rig, objects, hero, L)
        staged = out / (hero + '.generated.blend')
        bpy.ops.wm.save_as_mainfile(filepath=str(staged), check_existing=False)
        staged.replace(out / (hero + '.blend'))
    export(hero, rig, objects, out, checks, lengths)
