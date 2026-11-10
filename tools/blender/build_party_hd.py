"""Semirealistic party (iteration 1.4) assembled from user-installed Quaternius packs.

blender --background --factory-startup --python-exit-code 1 --python tools/blender/build_party_hd.py -- [--only=kael,lyra]

Inputs (git-ignored, installed with tools/install_quaternius.py from the user's own
itch.io downloads): Universal Base Characters, Modular Character Outfits - Fantasy and
Universal Animation Library. All three share one 65-bone skeleton.

Per hero: outfit + head of the base body + hairstyle, outfit texture recoloured to the
hero palette, hair tinted, a weapon/focus modelled here and attached to a hand, and the
clips required by KaelModel/CompanionModel baked from library animations through NLA.
Output: assets/third_party/party_hd/<hero>/<hero>.gltf (+ .bin, textures, manifest).
The output stays in assets/third_party/ (git-ignored): QAL forbids redistributing the
assets themselves, and the repository is public. Nothing here is committed but this script.
"""
import bpy, bmesh, json, math, sys, hashlib, colorsys
import numpy as np
from pathlib import Path
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[2]
Q = ROOT / 'assets/third_party/quaternius'
OUT = ROOT / 'assets/third_party/party_hd'
BASE = Q / 'universal-base-characters/Universal Base Characters[Standard]'
BODY = BASE / 'Base Characters/Godot - UE'
HAIR = BASE / 'Hairstyles/Rigged to Head Bone/glTF (Godot -Unreal)'
OUTFITS = Q / 'modular-character-outfits-fantasy/Modular Character Outfits - Fantasy[Standard]'
OUTFIT = OUTFITS / 'Exports/glTF (Godot-Unreal)/Outfits'
UAL = Q / 'universal-animation-library/Universal Animation Library[Standard]/Unreal-Godot'
argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
ONLY = next((a[7:].split(',') for a in argv if a.startswith('--only=')), None)
TEX_SIZE = 2048
WALK_CLIP = 'Jog_Fwd_Loop'

# A clip is a list of segments (library action, first frame, last frame, blend-in frames).
# Staff bearers idle with a bent arm and closed fist (torch idle) so the staff stands upright.
STAFF_IDLE = [('Idle_Torch_Loop', None, None, 0)]
STAFF_TAIL = ('Idle_Torch_Loop', 0, 8, 4)
SPELL = [('Spell_Simple_Enter', None, None, 0), ('Spell_Simple_Shoot', None, None, 2),
         ('Spell_Simple_Exit', None, None, 2)]
COMMON = {
    # Exploration moves at 4 m/s (playback capped at 2.5x): the jog cycle keeps feet planted.
    'Walk': [(WALK_CLIP, None, None, 0)],
    'Hurt': [('Hit_Chest', None, None, 0), ('Idle_Loop', 0, 8, 4)],
    'Defend': [('Idle_Loop', 0, 1, 0), ('Crouch_Idle_Loop', 0, 10, 8)],
    'KO': [('Death01', None, None, 0)],
}
HEROES = {
    'kael': dict(outfit='Male_Ranger', body='Superhero_Male_FullBody', hair='Hair_SimpleParted',
                 drop=('Hood',), hue=.60, sat=1.05, hair_rgb=(.20, .13, .09), height=2.1529555,
                 weapon='KaelSword', lunge=.5, grip=('Sword_Idle', 10, 'r'),
                 clips={'Idle': [('Sword_Idle', None, None, 0)],
                        'Attack': [('Sword_Attack', None, None, 0), ('Sword_Idle', 0, 8, 4)]},
                 durations={'Attack': .9, 'Hurt': .4, 'Defend': .45, 'KO': 1.2}),
    'lyra': dict(outfit='Female_Ranger', body='Superhero_Female_FullBody', hair='Hair_Long',
                 drop=('Hood',), hue=.73, sat=.85, hair_rgb=(.16, .10, .20), height=2.0516629,
                 weapon='Focus', lunge=0.0, crystal=(.62, .38, 1.0), grip=('Idle_Torch_Loop', 10, 'l'),
                 clips={'Idle': STAFF_IDLE, 'Attack': [('Punch_Jab', None, None, 0), STAFF_TAIL],
                        'Hurt': [('Hit_Chest', None, None, 0), STAFF_TAIL],
                        'Defend': [('Idle_Torch_Loop', 0, 1, 0), ('Crouch_Idle_Loop', 0, 10, 8)],
                        'Cast': SPELL + [STAFF_TAIL]},
                 durations={'Attack': .8, 'Hurt': .4, 'Defend': .45, 'KO': 1.2, 'Cast': .9}),
    'nira': dict(outfit='Female_Peasant', body='Superhero_Female_FullBody', hair='Hair_Buns',
                 drop=(), outfit_tex='Peasant/T_Peasant_2_BaseColor.png', hue=None, hair_rgb=(.42, .17, .07),
                 height=1.9317515, weapon='Focus', lunge=0.0, crystal=(.45, 1.0, .55), wood=(.10, .055, .028),
                 grip=('Idle_Torch_Loop', 10, 'l'),
                 clips={'Idle': STAFF_IDLE, 'Attack': [('Punch_Jab', None, None, 0), STAFF_TAIL],
                        'Hurt': [('Hit_Chest', None, None, 0), STAFF_TAIL],
                        'Defend': [('Idle_Torch_Loop', 0, 1, 0), ('Crouch_Idle_Loop', 0, 10, 8)],
                        'Support': [('Spell_Simple_Enter', None, None, 0), ('Spell_Simple_Idle_Loop', 0, 14, 3),
                                    ('Spell_Simple_Exit', None, None, 3), STAFF_TAIL]},
                 durations={'Attack': .8, 'Hurt': .4, 'Defend': .45, 'KO': 1.2, 'Support': .9}),
}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def import_gltf(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    new = [o for o in bpy.data.objects if o not in before]
    for o in [o for o in new if o.name.startswith('Icosphere')]:
        new.remove(o)
        bpy.data.objects.remove(o)
    return new


def relink_missing_images():
    """Some packs reference '<name>_png.png' or textures kept in sibling folders."""
    index = {}
    for p in Q.rglob('*.png'):
        index.setdefault(p.name.lower(), p)
    for img in bpy.data.images:
        if img.source != 'FILE' or (img.size[0] > 0 and img.has_data):
            continue
        name = Path(bpy.path.abspath(img.filepath)).name.lower()
        hit = index.get(name) or index.get(name.replace('_png.png', '.png'))
        if hit:
            img.filepath = str(hit)
            img.reload()


def adopt(meshes, armature):
    """Re-parent skinned meshes to the outfit armature (same bone names)."""
    for o in meshes:
        if o.type != 'MESH':
            continue
        world = o.matrix_world.copy()
        o.parent = armature
        o.matrix_world = world
        for m in o.modifiers:
            if m.type == 'ARMATURE':
                m.object = armature


def keep_head(obj, groups=('Head', 'neck_01')):
    """Outfits are made to be worn over the head only (pack readme)."""
    names = {g.index: g.name for g in obj.vertex_groups}
    keep = set()
    for v in obj.data.vertices:
        if v.groups:
            best = max(v.groups, key=lambda g: g.weight)
            if names.get(best.group) in groups:
                keep.add(v.index)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    doomed = [f for f in bm.faces if not all(v.index in keep for v in f.verts)]
    bmesh.ops.delete(bm, geom=doomed, context='FACES')
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    bm.to_mesh(obj.data)
    bm.free()


def pixels(img):
    px = np.empty(img.size[0] * img.size[1] * 4, np.float32)
    img.pixels.foreach_get(px)
    return px.reshape(-1, 4)


def store(img, px):
    img.pixels.foreach_set(px.ravel())
    img.update()


def rgb_to_hsv(rgb):
    mx, mn = rgb.max(1), rgb.min(1)
    d = mx - mn
    h = np.zeros_like(mx)
    safe = np.where(d > 1e-6, d, 1)
    r, g, b = rgb[:, 0], rgb[:, 1], rgb[:, 2]
    h = np.where(mx == r, ((g - b) / safe) % 6, h)
    h = np.where(mx == g, (b - r) / safe + 2, h)
    h = np.where(mx == b, (r - g) / safe + 4, h)
    h = np.where(d > 1e-6, h / 6, 0)
    s = np.where(mx > 1e-6, d / np.where(mx > 1e-6, mx, 1), 0)
    return h, s, mx


def hsv_to_rgb(h, s, v):
    i = np.floor(h * 6).astype(int) % 6
    f = h * 6 - np.floor(h * 6)
    p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
    choices = [np.stack(c, 1) for c in ((v, t, p), (q, v, p), (p, v, t), (p, q, v), (t, p, v), (v, p, q))]
    out = np.zeros((len(h), 3), np.float32)
    for k in range(6):
        out[i == k] = choices[k][i == k]
    return out


def recolor_greens(img, hue, sat_scale):
    """Ranger cloth is green: rotate only green hues so leather/metal stay as painted."""
    px = pixels(img)
    h, s, v = rgb_to_hsv(px[:, :3])
    weight = np.clip((s - .12) / .12, 0, 1) * np.clip(1 - np.abs(h - .30) / .14, 0, 1) ** .5
    shifted = hsv_to_rgb(np.full_like(h, hue), np.clip(s * sat_scale, 0, 1), v)
    px[:, :3] = px[:, :3] * (1 - weight[:, None]) + shifted * weight[:, None]
    store(img, px)


def tint_hair(img, rgb):
    px = pixels(img)
    lum = px[:, :3] @ np.array([.2126, .7152, .0722], np.float32)
    mask = px[:, 3] > .02
    mean = float(lum[mask].mean()) if mask.any() else .5
    px[:, :3] = np.clip(lum[:, None] / max(mean, 1e-3) * np.array(rgb, np.float32), 0, 1)
    store(img, px)


def material(name, color, metallic=0.0, roughness=.5, emission=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes['Principled BSDF']
    bsdf.inputs['Base Color'].default_value = (*color, 1)
    bsdf.inputs['Metallic'].default_value = metallic
    bsdf.inputs['Roughness'].default_value = roughness
    if emission:
        bsdf.inputs['Emission Color'].default_value = (*emission, 1)
        bsdf.inputs['Emission Strength'].default_value = 2.0
    return m


def lathe(bm, profile, segments, z0=0.0, mat=0):
    """Revolve [(radius, z)] around Z (staff shafts, grips, pommels)."""
    rings = []
    for r, z in profile:
        ring = [bm.verts.new((r * math.cos(2 * math.pi * k / segments), r * math.sin(2 * math.pi * k / segments), z0 + z))
                for k in range(segments)]
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for k in range(segments):
            f = bm.faces.new((a[k], a[(k + 1) % segments], b[(k + 1) % segments], b[k]))
            f.material_index = mat
            f.smooth = True
    for ring, flip in ((rings[0], True), (rings[-1], False)):
        if profile[0 if flip else -1][0] > 1e-4:
            f = bm.faces.new(list(reversed(ring)) if flip else ring)
            f.material_index = mat


def box(bm, size, centre, mat, bevel=0.0):
    geom = bmesh.ops.create_cube(bm, size=1.0)['verts']
    for v in geom:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2])) + Vector(centre)
    faces = {f for v in geom for f in v.link_faces}
    for f in faces:
        f.material_index = mat
    if bevel:
        edges = list({e for v in geom for e in v.link_edges})
        bmesh.ops.bevel(bm, geom=edges, offset=bevel, segments=2, affect='EDGES', profile=.5)


def blade(bm, length, width, thick, z0, mat):
    """Diamond-section blade with a fuller-less taper and a point."""
    stations = [(0.0, 1.0), (.55, .94), (.85, .72), (.97, .25), (1.0, 0.0)]
    rings = []
    for t, k in stations:
        z = z0 + t * length
        w, d = width * .5 * k, thick * .5 * max(k, .15)
        rings.append([bm.verts.new(p) for p in ((w, 0, z), (0, d, z), (-w, 0, z), (0, -d, z))])
    for a, b in zip(rings, rings[1:]):
        for k in range(4):
            bm.faces.new((a[k], a[(k + 1) % 4], b[(k + 1) % 4], b[k])).material_index = mat
    bm.faces.new(list(reversed(rings[0]))).material_index = mat


def crystal(bm, radius, height, z0, mat):
    top, bottom = bm.verts.new((0, 0, z0 + height)), bm.verts.new((0, 0, z0))
    ring = [bm.verts.new((radius * math.cos(k * math.pi / 3), radius * math.sin(k * math.pi / 3), z0 + height * .42))
            for k in range(6)]
    for k in range(6):
        bm.faces.new((ring[k], ring[(k + 1) % 6], top)).material_index = mat
        bm.faces.new((ring[(k + 1) % 6], ring[k], bottom)).material_index = mat


def build_weapon(hero, cfg):
    """Weapon in its own frame: grip centre at origin, blade/head along +Z."""
    bm = bmesh.new()
    if hero == 'kael':
        mats = [material('Steel', (.72, .74, .78), 1.0, .28), material('Brass', (.62, .46, .22), 1.0, .38),
                material('Leather', (.16, .09, .05), 0.0, .7)]
        lathe(bm, [(.016, -.11), (.018, -.06), (.017, 0), (.018, .06), (.016, .1)], 10, mat=2)       # grip
        lathe(bm, [(0, -.165), (.022, -.155), (.03, -.135), (.022, -.115), (.012, -.105)], 10, mat=1)  # pommel
        box(bm, (.24, .036, .028), (0, 0, .115), 1, bevel=.006)                                     # crossguard
        box(bm, (.06, .03, .04), (0, 0, .14), 1, bevel=.005)                                        # ricasso collar
        blade(bm, .92, .058, .011, .16, 0)
    else:
        wood = cfg.get('wood', (.035, .022, .03))
        mats = [material('StaffWood', wood, 0.0, .62), material('StaffMetal', (.70, .66, .58) if hero == 'lyra' else (.52, .42, .26), 1.0, .35),
                material('FocusCrystal', cfg['crystal'], 0.0, .12, emission=cfg['crystal'])]
        lathe(bm, [(0, -.62), (.016, -.6), (.017, -.2), (.018, .3), (.02, .66), (.026, .7), (.0, .74)], 16, mat=0)
        for z in (-.58, .62):
            lathe(bm, [(.021, z), (.024, z + .02), (.021, z + .05)], 16, mat=1)
        if hero == 'lyra':
            for k in range(3):   # three silver prongs cradle the crystal
                a = k * 2 * math.pi / 3
                p = [bm.verts.new(v) for v in ((.012 * math.cos(a), .012 * math.sin(a), .7), (.05 * math.cos(a), .05 * math.sin(a), .78),
                                                (.035 * math.cos(a), .035 * math.sin(a), .9), (.03 * math.cos(a + .25), .03 * math.sin(a + .25), .78))]
                bm.faces.new(p).material_index = 1
            crystal(bm, .04, .17, .74, 2)
        else:
            crystal(bm, .03, .12, .7, 2)
            for k in range(4):   # small carved leaves under the crystal
                a = k * math.pi / 2 + .4
                c, s_ = math.cos(a), math.sin(a)
                p = [bm.verts.new(v) for v in ((.018 * c, .018 * s_, .64), (.06 * c - .015 * s_, .06 * s_ + .015 * c, .69),
                                                (.09 * c, .09 * s_, .72), (.06 * c + .015 * s_, .06 * s_ - .015 * c, .67))]
                bm.faces.new(p).material_index = 1
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(cfg['weapon'])
    bm.to_mesh(mesh)
    bm.free()
    for m in mats:
        mesh.materials.append(m)
    obj = bpy.data.objects.new(cfg['weapon'], mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def attach_weapon(obj, arm, pose_action, frame, side):
    """Fit the weapon into a closed fist of a library pose, then bone-parent it to that hand.
    Staffs go in the left hand: the torch idle raises a vertical left fist, while the
    right hand hangs open (and the spell clips cast with the left hand, staff in it)."""
    arm.animation_data.action = bpy.data.actions[pose_action]
    if hasattr(arm.animation_data, 'action_slot') and bpy.data.actions[pose_action].slots:
        arm.animation_data.action_slot = bpy.data.actions[pose_action].slots[0]
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()
    pb = arm.pose.bones
    W = arm.matrix_world
    head = lambda b: W @ pb[b].head
    hand = 'hand_' + side
    knuckles = [head('%s_02_%s' % (f, side)) for f in ('index', 'middle', 'ring', 'pinky')]
    centre = (sum(knuckles, Vector()) / 4 + head(hand)) / 2
    up = (head('index_02_' + side) - head('pinky_02_' + side)).normalized()   # thumb side = blade direction
    palm = (centre - head(hand)).normalized()
    x = palm.cross(up).normalized()
    y = up.cross(x).normalized()
    obj.matrix_world = Matrix((x, y, up)).transposed().to_4x4()
    obj.matrix_world.translation = centre
    world = obj.matrix_world.copy()
    obj.parent = arm
    obj.parent_type = 'BONE'
    obj.parent_bone = hand
    bpy.context.view_layer.update()
    obj.matrix_world = world
    arm.animation_data.action = None
    bpy.context.view_layer.update()


def bake_clip(arm, name, segments):
    ad = arm.animation_data
    ad.action = None
    for t in list(ad.nla_tracks):
        ad.nla_tracks.remove(t)
    frame = 0
    for action_name, a, b, blend in segments:
        act = bpy.data.actions[action_name]
        a = act.frame_range[0] if a is None else a
        b = act.frame_range[1] if b is None else b
        start = max(0, frame - blend)
        track = ad.nla_tracks.new()
        strip = track.strips.new(action_name, int(start), act)
        if hasattr(strip, 'action_slot') and act.slots:
            strip.action_slot = act.slots[0]
        strip.action_frame_start, strip.action_frame_end = a, b
        strip.frame_start_ui = start
        strip.frame_end_ui = start + (b - a)
        strip.blend_in = blend
        strip.extrapolation = 'HOLD_FORWARD'
        strip.use_sync_length = False
        frame = start + (b - a)
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode='POSE')
    bpy.ops.pose.select_all(action='SELECT')
    bpy.ops.nla.bake(frame_start=0, frame_end=int(math.ceil(frame)), step=1, only_selected=False, visual_keying=False,
                     clear_constraints=False, clear_parents=False, use_current_action=False, clean_curves=False,
                     bake_types={'POSE'})
    bpy.ops.object.mode_set(mode='OBJECT')
    baked = ad.action
    baked.name = name
    baked.use_fake_user = True
    ad.action = None
    for t in list(ad.nla_tracks):
        ad.nla_tracks.remove(t)
    return baked


def walk_speed():
    """Ground speed of the walk clip at library scale, from the root-motion variant."""
    before = set(bpy.data.actions)
    objs = import_gltf(UAL / 'UAL1_Standard_RM.glb')
    arm = next(o for o in objs if o.type == 'ARMATURE')
    act = next(a for a in bpy.data.actions if a not in before and a.name.startswith(WALK_CLIP))
    arm.animation_data_create()
    arm.animation_data.action = act
    if hasattr(arm.animation_data, 'action_slot') and act.slots:
        arm.animation_data.action_slot = act.slots[0]
    a, b = act.frame_range
    pts = []
    for f in (a, b):
        bpy.context.scene.frame_set(int(f))
        bpy.context.view_layer.update()
        pts.append(arm.matrix_world @ arm.pose.bones['root'].head)
    seconds = (b - a) / bpy.context.scene.render.fps
    speed = Vector((pts[1] - pts[0]).xy).length / seconds
    for o in objs:
        bpy.data.objects.remove(o)
    for x in [x for x in bpy.data.actions if x not in before]:
        bpy.data.actions.remove(x)
    return speed


def tris(objs):
    total = 0
    for o in objs:
        if o.type == 'MESH':
            total += sum(len(p.vertices) - 2 for p in o.data.polygons)
    return total


def write_texture_imports(folder):
    """VRAM-compressed, mipmapped textures (the HD forest learned this the hard way)."""
    for png in folder.glob('*.png'):
        imp = png.with_name(png.name + '.import')
        if not imp.exists():
            imp.write_text('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\n'
                           'compress/mode=2\nmipmaps/generate=true\ndetect_3d/compress_to=0\n', encoding='utf-8')


def build(hero, cfg, library_speed):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    outfit = import_gltf(OUTFIT / (cfg['outfit'] + '.gltf'))
    arm = next(o for o in outfit if o.type == 'ARMATURE')
    arm.name = 'Armature'
    for o in [o for o in outfit if o.type == 'MESH' and any(d in o.name for d in cfg['drop'])]:
        outfit.remove(o)
        bpy.data.objects.remove(o)
    body = import_gltf(BODY / (cfg['body'] + '.gltf'))
    body_arm = next(o for o in body if o.type == 'ARMATURE')
    skin = next(o for o in body if o.type == 'MESH' and o.name.lower().startswith('superhero'))
    keep_head(skin)
    hair = import_gltf(HAIR / (cfg['hair'] + '.gltf'))
    hair_arm = [o for o in hair if o.type == 'ARMATURE']
    adopt([o for o in body + hair if o.type == 'MESH'], arm)
    for o in [body_arm] + hair_arm:
        bpy.data.objects.remove(o)
    relink_missing_images()

    # Textures: downscale, recolour cloth, tint hair.
    for img in list(bpy.data.images):
        if img.size[0] > TEX_SIZE:
            img.scale(TEX_SIZE, TEX_SIZE)
    if cfg.get('outfit_tex'):
        alt = bpy.data.images.load(str(OUTFITS / 'Textures' / cfg['outfit_tex']))
        alt.scale(TEX_SIZE, TEX_SIZE)
        for img in list(bpy.data.images):
            if img != alt and 'BaseColor' in img.name and cfg['outfit'].split('_')[1] in img.name:
                img.user_remap(alt)
        alt.name = Path(cfg['outfit_tex']).stem
    for img in bpy.data.images:
        if cfg['hue'] is not None and img.name.startswith('T_Ranger') and 'BaseColor' in img.name:
            recolor_greens(img, cfg['hue'], cfg['sat'])
        if img.name.startswith('T_Hair') and 'BaseColor' in img.name:
            tint_hair(img, cfg['hair_rgb'])

    # Library clips.
    before = set(bpy.data.actions)
    ual = import_gltf(UAL / 'UAL1_Standard.glb')
    for o in ual:
        bpy.data.objects.remove(o)
    library = {a.name.split('.')[0]: a for a in bpy.data.actions if a not in before}
    for a in library.values():
        a.name = a.name.split('.')[0]
        a.use_fake_user = True
    arm.animation_data_create()
    weapon = build_weapon(hero, cfg)
    attach_weapon(weapon, arm, *cfg['grip'])
    clips = dict(COMMON, **cfg['clips'])
    baked = {name: bake_clip(arm, name, segs) for name, segs in clips.items()}
    for a in list(library.values()):
        bpy.data.actions.remove(a)
    for a in [a for a in bpy.data.actions if a.name not in baked]:
        bpy.data.actions.remove(a)

    # Scale to the hero's established in-game height (rest pose, hair included).
    arm.data.pose_position = 'REST'
    bpy.context.view_layer.update()
    meshes = [o for o in bpy.data.objects if o.type == 'MESH' and o != weapon]
    zs = [(o.matrix_world @ Vector(c)).z for o in meshes for c in o.bound_box]
    measured = max(zs) - min(zs)
    arm.data.pose_position = 'POSE'
    scale = cfg['height'] / measured
    arm.scale = (scale,) * 3
    bpy.context.view_layer.update()

    folder = OUT / hero
    folder.mkdir(parents=True, exist_ok=True)
    for old in folder.glob('*'):
        if old.suffix in ('.gltf', '.bin', '.png'):
            old.unlink()
    path = folder / (hero + '.gltf')
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLTF_SEPARATE', export_yup=True,
                              export_animations=True, export_animation_mode='ACTIONS', export_anim_slide_to_zero=True,
                              export_force_sampling=True, export_frame_step=1, export_image_format='AUTO',
                              export_apply=False, export_skins=True, export_def_bones=False)
    write_texture_imports(folder)
    fps = scene.render.fps
    lengths = {n: round((a.frame_range[1] - a.frame_range[0]) / fps, 3) for n, a in baked.items()}
    durations = dict(lengths)
    durations.update(cfg['durations'])
    manifest = {
        'character': hero,
        'art_revision': 'party-hd-quaternius',
        'blender': bpy.app.version_string,
        'method': 'Quaternius CC0 base head + outfit + hairstyle (user-installed, not redistributed), recoloured; '
                  'library animations baked to game clips; weapon/focus modelled by this script',
        'sources': {'outfit': cfg['outfit'], 'body': cfg['body'] + ' (head only)', 'hair': cfg['hair'],
                    'animations': 'UAL1_Standard', 'outfit_texture': cfg.get('outfit_tex', 'default')},
        'triangles': tris(bpy.data.objects),
        'bones': len(arm.data.bones),
        'height': cfg['height'],
        'scale': scale,
        'animations': sorted(baked),
        'clip_seconds': lengths,
        'walk_reference_speed': library_speed * scale,
        'locomotion_blend': .15,
        'lunge_distance': cfg['lunge'],
        'presentation_durations': durations,
        'authored_sections': len(meshes) + 1,
        'gltf_sha256': sha(path),
    }
    (folder / (hero + '_manifest.json')).write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print('BUILT', hero, json.dumps({k: manifest[k] for k in ('triangles', 'scale', 'clip_seconds', 'walk_reference_speed')}), flush=True)


assert bpy.app.background, 'Use a separate background Blender process'
missing = [p for p in (BODY, HAIR, OUTFIT, UAL) if not p.exists()]
if missing:
    sys.exit('Quaternius packs not installed (run tools/install_quaternius.py first): %s' % missing)
bpy.ops.wm.read_factory_settings(use_empty=True)
speed = walk_speed()
OUT.mkdir(parents=True, exist_ok=True)
for hero, cfg in HEROES.items():
    if ONLY and hero not in ONLY:
        continue
    build(hero, cfg, speed)
