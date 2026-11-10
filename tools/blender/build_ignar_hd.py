"""Ignar HD (iteration 1.7): the fire Guardian in the same pipeline as the HD party.

blender --background --factory-startup --python-exit-code 1 --python tools/blender/build_ignar_hd.py [-- --seed=17]

Follows the designer's Ignar sheet (lava core in the chest, obsidian plates over a
molten body, horned head with glowing eyes, ember mane added in-game as particles)
on the same Quaternius 65-bone skeleton and Universal Animation Library as Kael,
Lyra and Nira, so it moves and is lit like them. The base body becomes the molten
interior: inflated a little and given an emissive lava material; obsidian plates
are generated around every bone (rigid, one bone per plate, sized from the body
around that bone) and leave glowing seams between them.

Inputs: the user-installed Quaternius packs (git-ignored). Output, also git-ignored
(the packs may not be redistributed): assets/third_party/ignar_hd/ignar.gltf (+ .bin,
textures, manifest). Textures are generated here with numpy (tileable noise).
"""
import bpy, bmesh, json, math, sys
import numpy as np
from pathlib import Path
from mathutils import Vector, Matrix

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_party_hd as party   # shared import/bake/export helpers (same pipeline)

ROOT = party.ROOT
OUT = ROOT / 'assets/third_party/ignar_hd'
argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
SEED = int(next((a[7:] for a in argv if a.startswith('--seed=')), 17))
rng = np.random.default_rng(SEED)
HEIGHT = 4.2          # metres, close to the previous summon (procedural golem x1.55)
TEX = 1024
TMP = Path(__import__('tempfile').gettempdir()) / 'ignar_hd_textures'
CLIPS = {
    'Idle': [('Idle_Loop', None, None, 0)],
    'Appear': [('Jump_Land', None, None, 0), ('Idle_Loop', 0, 10, 6)],
    'Attack': [('Punch_Cross', None, None, 0), ('Idle_Loop', 0, 10, 6)],
}
# Blow contact inside the Attack clip (fraction), read by the game for the impact.
ATTACK_CONTACT = 0.42

# Plates per bone: rings along the bone, plates per ring, size and bulk multipliers.
PLATES = {
    'pelvis': (1, 6, 1.0, 1.0), 'spine_01': (1, 6, 1.0, 1.05), 'spine_02': (1, 7, 1.05, 1.1),
    'spine_03': (2, 7, 1.1, 1.2), 'neck_01': (1, 5, 0.9, 1.0),
    'clavicle_l': (1, 3, 1.4, 1.3), 'clavicle_r': (1, 3, 1.4, 1.3),
    'upperarm_l': (2, 5, 1.3, 1.4), 'upperarm_r': (2, 5, 1.3, 1.4),
    'lowerarm_l': (2, 5, 1.35, 1.55), 'lowerarm_r': (2, 5, 1.35, 1.55),
    'thigh_l': (2, 5, 1.15, 1.25), 'thigh_r': (2, 5, 1.15, 1.25),
    'calf_l': (2, 5, 1.15, 1.3), 'calf_r': (2, 5, 1.15, 1.3),
}
CORE_RADIUS = 0.12


# ---------------------------------------------------------------- textures
def fractal(size, octaves=6, falloff=0.55, seed_shift=0):
    """Tileable fractal noise in [0, 1] (FFT-filtered white noise)."""
    out = np.zeros((size, size))
    amp = 1.0
    for o in range(octaves):
        cells = 4 * 2 ** o
        base = rng.standard_normal((cells, cells))
        spectrum = np.fft.fft2(base)
        up = np.zeros((size, size), complex)
        h = cells // 2
        up[:h, :h], up[:h, -h:], up[-h:, :h], up[-h:, -h:] = spectrum[:h, :h], spectrum[:h, -h:], spectrum[-h:, :h], spectrum[-h:, -h:]
        layer = np.real(np.fft.ifft2(up))
        out += amp * layer / (np.abs(layer).max() + 1e-9)
        amp *= falloff
    out -= out.min()
    return out / out.max()


def image(name, rgb, alpha=None, colorspace='sRGB'):
    img = bpy.data.images.new(name, TEX, TEX, alpha=False)
    # Colour space first: changing it regenerates a generated image's buffer.
    img.colorspace_settings.name = colorspace
    px = np.ones((TEX, TEX, 4), np.float32)
    px[..., :3] = rgb
    img.pixels.foreach_set(px.ravel())
    # Save to a file: packing a generated image stores its blank initial content.
    TMP.mkdir(parents=True, exist_ok=True)
    img.filepath_raw = str(TMP / (name + '.png'))
    img.file_format = 'PNG'
    img.save()
    return img


def textures():
    height = fractal(TEX, 7, 0.55)
    grain = fractal(TEX, 4, 0.8)
    # Obsidian: near-black with violet/brown cast, lighter worn ridges.
    tone = 0.10 + 0.16 * height ** 1.4 + 0.04 * grain
    obsidian = np.stack([tone * 1.12, tone * 0.86, tone * 0.9], -1)
    gy, gx = np.gradient(height * 6.0)
    normal = np.stack([-gx, -gy, np.ones_like(gx)], -1)
    normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
    normal = normal * 0.5 + 0.5
    # Lava: bright yellow-orange veins (ridged noise) over deep red.
    ridge = 1.0 - np.abs(fractal(TEX, 6, 0.6) * 2 - 1)
    veins = np.clip((ridge - 0.55) / 0.45, 0, 1) ** 1.6
    heat = 0.25 + 0.75 * veins
    lava = np.stack([np.clip(0.62 + 0.38 * heat, 0, 1), np.clip(0.10 + 0.55 * heat ** 1.5, 0, 1), np.clip(0.01 + 0.12 * heat ** 3, 0, 1)], -1)
    return (image('T_Ignar_Obsidian', obsidian), image('T_Ignar_Obsidian_N', normal, colorspace='Non-Color'),
            image('T_Ignar_Lava', lava))


def principled(name, base=None, base_tex=None, normal_tex=None, emission_tex=None, emission=None, strength=0.0, roughness=0.5, metallic=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nodes, links = m.node_tree.nodes, m.node_tree.links
    bsdf = nodes['Principled BSDF']
    bsdf.inputs['Roughness'].default_value = roughness
    bsdf.inputs['Metallic'].default_value = metallic
    if base is not None:
        bsdf.inputs['Base Color'].default_value = (*base, 1)
    if base_tex is not None:
        t = nodes.new('ShaderNodeTexImage')
        t.image = base_tex
        links.new(t.outputs['Color'], bsdf.inputs['Base Color'])
    if normal_tex is not None:
        t = nodes.new('ShaderNodeTexImage')
        t.image = normal_tex
        nm = nodes.new('ShaderNodeNormalMap')
        links.new(t.outputs['Color'], nm.inputs['Color'])
        links.new(nm.outputs['Normal'], bsdf.inputs['Normal'])
    if emission_tex is not None:
        t = nodes.new('ShaderNodeTexImage')
        t.image = emission_tex
        links.new(t.outputs['Color'], bsdf.inputs['Emission Color'])
    elif emission is not None:
        bsdf.inputs['Emission Color'].default_value = (*emission, 1)
    bsdf.inputs['Emission Strength'].default_value = strength
    return m


# ---------------------------------------------------------------- geometry
def rock(bm, centre, axes, size, mat, subdivisions=0, jitter=0.16):
    """Angular obsidian chunk: a jittered icosphere squashed into a plate."""
    geom = bmesh.ops.create_icosphere(bm, subdivisions=subdivisions, radius=1.0)
    x, y, z = axes
    for v in geom['verts']:
        p = v.co * (1.0 + rng.uniform(-jitter, jitter))
        v.co = centre + x * (p.x * size[0]) + y * (p.y * size[1]) + z * (p.z * size[2])
    for f in {f for v in geom['verts'] for f in v.link_faces}:
        f.material_index = mat
        f.smooth = False
    return geom['verts']


def cone(bm, base, direction, length, radius, mat, bend=Vector((0, 0, 0)), rings=5, sides=6):
    """Tapered horn/spike along a curve (base -> tip), bending towards `bend`."""
    direction = direction.normalized()
    ref = Vector((0, 0, 1)) if abs(direction.z) < 0.9 else Vector((1, 0, 0))
    u = direction.cross(ref).normalized()
    w = direction.cross(u).normalized()
    verts_rings = []
    for i in range(rings):
        t = i / (rings - 1)
        centre = base + direction * (length * t) + bend * (t * t)
        r = radius * (1 - t) ** 0.9 + 0.002
        verts_rings.append([bm.verts.new(centre + (u * math.cos(k * 2 * math.pi / sides) + w * math.sin(k * 2 * math.pi / sides)) * r)
                            for k in range(sides)])
    made = [v for ring in verts_rings for v in ring]
    for a, b in zip(verts_rings, verts_rings[1:]):
        for k in range(sides):
            f = bm.faces.new((a[k], a[(k + 1) % sides], b[(k + 1) % sides], b[k]))
            f.material_index = mat
    cap = bm.faces.new(list(reversed(verts_rings[0])))
    cap.material_index = mat
    return made


def frame_for(axis):
    ref = Vector((0, 0, 1)) if abs(axis.z) < 0.85 else Vector((1, 0, 0))
    u = axis.cross(ref).normalized()
    return u, axis.cross(u).normalized()


def bone_points(arm, body, inflate):
    """Body vertices (rest pose, world space) grouped by their dominant bone."""
    names = {g.index: g.name for g in body.vertex_groups}
    groups = {}
    mw = body.matrix_world
    for v in body.data.vertices:
        if not v.groups:
            continue
        best = max(v.groups, key=lambda g: g.weight)
        groups.setdefault(names[best.group], []).append(mw @ (v.co + v.normal * inflate))
    return groups


def build_plates(arm, groups, forward, mats, core=None):
    """One bmesh per bone, rigidly weighted to it; returns the created objects."""
    W = arm.matrix_world
    created = []
    for bone_name, (rings, around, size_k, bulk) in PLATES.items():
        bone = arm.data.bones[bone_name]
        head, tail = W @ bone.head_local, W @ bone.tail_local
        axis = (tail - head)
        length = axis.length
        axis.normalize()
        u, w = frame_for(axis)
        pts = groups.get(bone_name, [])
        if not pts:
            continue
        rel = np.array([[(p - head).dot(axis), (p - head).dot(u), (p - head).dot(w)] for p in pts])
        ang = np.arctan2(rel[:, 2], rel[:, 1])
        dist = np.hypot(rel[:, 1], rel[:, 2])
        lo, hi = np.percentile(rel[:, 0], 5), np.percentile(rel[:, 0], 95)
        bm = bmesh.new()
        for i in range(rings):
            t = lo + (hi - lo) * (i + 0.5) / rings
            for k in range(around):
                theta = (k + 0.5 * (i % 2)) / around * 2 * math.pi + rng.uniform(-0.12, 0.12)
                sector = np.abs((ang - theta + math.pi) % (2 * math.pi) - math.pi) < (math.pi / around * 1.3)
                band = np.abs(rel[:, 0] - t) < (hi - lo) / rings
                sel = dist[sector & band] if np.any(sector & band) else dist[sector] if np.any(sector) else dist
                radius = float(np.percentile(sel, 85)) if len(sel) else 0.05
                radial = u * math.cos(theta) + w * math.sin(theta)
                arc = 2 * math.pi * max(radius, 0.03) / around
                thick = (0.026 + 0.014 * rng.random()) * size_k
                centre = head + axis * t + radial * (radius + thick * 0.6 * bulk + 0.01 * bulk)
                # The chest core stays uncovered (front of the upper torso).
                if core is not None and radial.dot(forward) > 0.55 and (centre - core).length < CORE_RADIUS * 2.1:
                    continue
                tangent = radial.cross(axis).normalized()
                size = (arc * 0.56 * size_k * bulk, thick, (hi - lo) / rings * 0.6 * size_k)
                twist = Matrix.Rotation(rng.uniform(-0.2, 0.2), 3, radial)
                rock(bm, centre, (twist @ tangent, radial, twist @ axis), size, mats['obsidian'], 0)
        created.append(finish_part(bm, bone_name, arm))
    return created


def finish_part(bm, bone_name, arm, name=None):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name or ('Plates_' + bone_name))
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(mesh.name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    group = obj.vertex_groups.new(name=bone_name)
    group.add(range(len(mesh.vertices)), 1.0, 'REPLACE')
    obj.parent = arm
    obj.matrix_parent_inverse = arm.matrix_world.inverted()   # geometry is in world space
    mod = obj.modifiers.new('Armature', 'ARMATURE')
    mod.object = arm
    return obj


def build_details(arm, forward, mats, groups, core_at):
    """Fists, feet, head with horns and eyes, shoulder spikes, chest core."""
    W = arm.matrix_world
    pos = lambda b: W @ arm.data.bones[b].head_local
    tail = lambda b: W @ arm.data.bones[b].tail_local
    up = Vector((0, 0, 1))
    side = forward.cross(up).normalized()
    parts = []
    for s in ('l', 'r'):
        # Fist: a cluster of heavy knuckle chunks around the hand.
        hand, knuckle = pos('hand_' + s), pos('middle_02_' + s)
        axis = (knuckle - hand).normalized()
        u, w = frame_for(axis)
        bm = bmesh.new()
        rock(bm, (hand + knuckle) * 0.5, (u, w, axis), (0.075, 0.07, 0.085), mats['obsidian'], 1)
        for k in range(4):
            a = k / 4 * 2 * math.pi
            rock(bm, knuckle + (u * math.cos(a) + w * math.sin(a)) * 0.05, (u, w, axis), (0.045, 0.04, 0.05), mats['obsidian'], 0)
        parts.append(finish_part(bm, 'hand_' + s, arm, 'Fist_' + s))
        # Feet: wide stone blocks.
        foot, ball = pos('foot_' + s), pos('ball_' + s)
        axis = (ball - foot).normalized()
        u, w = frame_for(axis)
        bm = bmesh.new()
        rock(bm, foot.lerp(ball, 0.45) + Vector((0, 0, -0.01)), (u, w, axis), (0.09, 0.07, 0.13), mats['obsidian'], 1)
        rock(bm, ball + axis * 0.04, (u, w, axis), (0.075, 0.05, 0.06), mats['obsidian'], 0)
        parts.append(finish_part(bm, 'foot_' + s, arm, 'Foot_' + s))
        # Shoulder spikes (sheet: jagged obsidian shoulders).
        shoulder = pos('upperarm_' + s)
        out = (shoulder - pos('spine_03')).normalized()
        out.z = 0
        out.normalize()
        bm = bmesh.new()
        for k, (lift, spread, length) in enumerate(((0.95, 0.15, 0.22), (0.7, 0.55, 0.17), (0.55, -0.2, 0.14))):
            d = (up * lift + out * (0.6 + spread) + forward * (0.1 * k - 0.1)).normalized()
            cone(bm, shoulder + up * 0.06 + out * 0.03, d, length, 0.045, mats['obsidian'], sides=5)
        parts.append(finish_part(bm, 'clavicle_' + s, arm, 'Spikes_' + s))
    # Head: built over the body's own head (its vertices), so no lava pokes out:
    # a heavy faceted skull, brow, jaw, glowing eyes, two horns and a crest.
    pts = np.array([tuple(p) for p in groups.get('Head', [pos('Head')])])
    lo_, hi_ = pts.min(0), pts.max(0)
    centre = Vector(((lo_ + hi_) / 2).tolist())
    ext = Vector(((hi_ - lo_) / 2).tolist())
    half_w = max(abs(ext.dot(side)), 0.08)
    half_d = max(abs(ext.dot(forward)), 0.08)
    half_h = max(ext.z, 0.1)
    bm = bmesh.new()
    rock(bm, centre + up * 0.01, (side, forward, up), (half_w * 1.35, half_d * 1.3, half_h * 1.25), mats['obsidian'], 1, 0.08)
    face = centre + forward * (half_d * 1.12)
    rock(bm, face + up * (half_h * 0.28), (side, forward, up), (half_w * 1.25, 0.045, 0.04), mats['obsidian'], 0, 0.08)    # brow
    rock(bm, face - up * (half_h * 0.55), (side, forward, up), (half_w * 0.95, 0.06, 0.07), mats['obsidian'], 0, 0.1)     # jaw
    for s in (-1, 1):
        rock(bm, face + forward * 0.035 + up * (half_h * 0.08) + side * (half_w * 0.42 * s), (side, forward, up), (0.03, 0.012, 0.013), mats['glow'], 0, 0.04)
        temple = centre + side * (half_w * 1.05 * s) + up * (half_h * 0.55)
        cone(bm, temple, (side * s * 0.85 + up * 0.55).normalized(), 0.26, 0.05, mats['obsidian'], bend=up * 0.2 - side * s * 0.04, rings=6)
    cone(bm, centre + up * (half_h * 1.1) + forward * 0.04, (up + forward * 0.2).normalized(), 0.2, 0.045, mats['obsidian'], rings=5)
    parts.append(finish_part(bm, 'Head', arm, 'HeadRock'))
    # Lava core: bright sphere in the chest opening, with a rim of plates.
    bm = bmesh.new()
    geom = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=CORE_RADIUS)
    for v in geom['verts']:
        v.co += core_at
    for f in bm.faces:
        f.material_index = mats['core']
        f.smooth = True
    for k in range(8):
        a = k / 8 * 2 * math.pi
        radial = side * math.cos(a) + up * math.sin(a)
        rock(bm, core_at + radial * (CORE_RADIUS * 1.35) - forward * 0.01, (radial.cross(forward).normalized(), forward, radial), (0.05, 0.03, 0.04), mats['obsidian'], 0)
    parts.append(finish_part(bm, 'spine_03', arm, 'Core'))
    return parts


def triplanar_uvs(obj, scale=2.2):
    me = obj.data
    if not me.uv_layers:
        me.uv_layers.new(name='UVMap')
    bm = bmesh.new()
    bm.from_mesh(me)
    uv = bm.loops.layers.uv.active
    for f in bm.faces:
        n = f.normal
        axis = max(range(3), key=lambda i: abs(n[i]))
        a, b = [(1, 2), (0, 2), (0, 1)][axis]
        for loop in f.loops:
            co = loop.vert.co
            loop[uv].uv = (co[a] * scale, co[b] * scale)
    bm.to_mesh(me)
    bm.free()


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    objs = party.import_gltf(party.BODY / 'Superhero_Male_FullBody.gltf')
    arm = next(o for o in objs if o.type == 'ARMATURE')
    arm.name = 'Armature'
    body = next(o for o in objs if o.type == 'MESH' and o.name.lower().startswith('superhero'))
    for o in [o for o in objs if o.type == 'MESH' and o != body]:
        bpy.data.objects.remove(o)
    obsidian_tex, normal_tex, lava_tex = textures()
    materials = [
        principled('IgnarObsidian', base_tex=obsidian_tex, normal_tex=normal_tex, roughness=0.32, metallic=0.15),
        principled('IgnarLava', base_tex=lava_tex, emission_tex=lava_tex, strength=1.8, roughness=0.6),
        principled('IgnarGlow', base=(1.0, 0.75, 0.3), emission=(1.0, 0.72, 0.25), strength=8.0),
        principled('IgnarCore', base=(1.0, 0.7, 0.3), emission=(1.0, 0.62, 0.22), strength=6.0),
    ]
    mats = {'obsidian': 0, 'lava': 1, 'glow': 2, 'core': 3}
    # Molten body: inflated along normals, single lava material.
    inflate = 0.012
    for v in body.data.vertices:
        v.co += v.normal * inflate
    body.data.materials.clear()
    body.data.materials.append(materials[1])
    for p in body.data.polygons:
        p.material_index = 0
    body.name = 'IgnarMagma'
    W = arm.matrix_world
    ball = W @ arm.data.bones['ball_l'].head_local
    foot = W @ arm.data.bones['foot_l'].head_local
    forward = Vector(((ball - foot).x, (ball - foot).y, 0)).normalized()
    groups = bone_points(arm, body, 0.0)
    # Core at the front of the upper chest, just proud of the body surface.
    chest = groups.get('spine_03', [])
    spine = W @ arm.data.bones['spine_03'].head_local
    front = max((p - spine).dot(forward) for p in chest) if chest else 0.12
    core_at = spine + Vector((0, 0, 0.06)) + forward * (front - CORE_RADIUS * 0.35)
    parts = build_plates(arm, groups, forward, mats, core_at) + build_details(arm, forward, mats, groups, core_at)
    for p in parts:
        for m in materials:
            p.data.materials.append(m)
        triplanar_uvs(p)
    # One mesh for every plate (one draw call per material), still one bone per vertex.
    bpy.ops.object.select_all(action='DESELECT')
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    plates = bpy.context.view_layer.objects.active
    plates.name = 'IgnarPlates'
    # Library clips baked through NLA, exactly like the party.
    before = set(bpy.data.actions)
    ual = party.import_gltf(party.UAL / 'UAL1_Standard.glb')
    for o in ual:
        bpy.data.objects.remove(o)
    library = {a.name.split('.')[0]: a for a in bpy.data.actions if a not in before}
    for a in library.values():
        a.name = a.name.split('.')[0]
        a.use_fake_user = True
    arm.animation_data_create()
    baked = {name: party.bake_clip(arm, name, segs) for name, segs in CLIPS.items()}
    for a in list(library.values()):
        bpy.data.actions.remove(a)
    for a in [a for a in bpy.data.actions if a.name not in baked]:
        bpy.data.actions.remove(a)
    # Scale to the summon's height (rest pose).
    arm.data.pose_position = 'REST'
    bpy.context.view_layer.update()
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    zs = [(o.matrix_world @ Vector(c)).z for o in meshes for c in o.bound_box]
    measured = max(zs) - min(zs)
    arm.data.pose_position = 'POSE'
    scale = HEIGHT / measured
    arm.scale = (scale,) * 3
    bpy.context.view_layer.update()

    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob('*'):
        if old.suffix in ('.gltf', '.bin', '.png'):
            old.unlink()
    path = OUT / 'ignar.gltf'
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLTF_SEPARATE', export_yup=True,
                              export_animations=True, export_animation_mode='ACTIONS', export_anim_slide_to_zero=True,
                              export_force_sampling=True, export_frame_step=1, export_image_format='AUTO',
                              export_apply=False, export_skins=True, export_def_bones=False)
    party.write_texture_imports(OUT)
    fps = bpy.context.scene.render.fps
    lengths = {n: round((a.frame_range[1] - a.frame_range[0]) / fps, 3) for n, a in baked.items()}
    manifest = {
        'character': 'ignar',
        'art_revision': 'ignar-hd-quaternius',
        'blender': bpy.app.version_string,
        'method': 'Quaternius CC0 base body (user-installed, not redistributed) as an emissive molten core; obsidian plates, '
                  'fists, horns, eyes and chest core generated by this script (rigid, one bone each); textures generated with '
                  'numpy; Universal Animation Library clips baked to game clips. Design: the designer\'s Ignar sheet.',
        'sources': {'body': 'Superhero_Male_FullBody', 'animations': 'UAL1_Standard', 'seed': SEED},
        'triangles': party.tris(bpy.data.objects),
        'bones': len(arm.data.bones),
        'height': HEIGHT,
        'scale': scale,
        'animations': sorted(baked),
        'clip_seconds': lengths,
        'attack_contact': ATTACK_CONTACT,
        'authored_sections': len(parts) + 1,
        'gltf_sha256': party.sha(path),
    }
    (OUT / 'ignar_manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print('BUILT ignar', json.dumps({k: manifest[k] for k in ('triangles', 'scale', 'clip_seconds', 'authored_sections')}), flush=True)


if __name__ == '__main__':
    assert bpy.app.background, 'Use a separate background Blender process'
    if not party.BODY.exists() or not party.UAL.exists():
        sys.exit('Quaternius packs not installed (run tools/install_quaternius.py first)')
    build()
