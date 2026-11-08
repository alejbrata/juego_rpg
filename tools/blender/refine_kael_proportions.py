"""Isolated proportion study of the saved 0.9 mesh, not a new character generator.

Run in a separate Blender background process. Never replaces the playable asset.
The original UVs, atlas, topology and animation keys remain provisional.
"""
import hashlib
import json
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/characters/kael/kael.blend"
OUT = ROOT / "assets/characters/kael/proportion_study"


def lerp_profile(value, points):
    for (a, b), (c, d) in zip(points, points[1:]):
        if value <= c:
            return b + (d - b) * (value - a) / (c - a)
    a, b = points[-2]
    c, d = points[-1]
    return b + (d - b) * (value - a) / (c - a)


def reshape(point):
    x, y, z = point
    height = lerp_profile(z, [(0, 0), (.2, .19), (.50, .59), (.9, 1.10),
                               (1.505, 1.64), (2.15, 2.04)])
    width = lerp_profile(z, [(0, .78), (1.40, .78), (1.535, .63), (2.2, .63)])
    depth = lerp_profile(z, [(0, .83), (1.40, .82), (1.535, .65), (2.2, .65)])
    return Vector((x * width, y * depth, height))


if not bpy.app.background:
    raise RuntimeError("Use --background --factory-startup; never replace a live scene")
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
OUT.mkdir(parents=True, exist_ok=True)
rig = bpy.data.objects["KaelRig"]
body = bpy.data.objects["KaelBody"]
sword = bpy.data.objects["KaelSword"]
assert rig.matrix_world == body.matrix_world == sword.matrix_world
rig.animation_data.action = None
rig.data.pose_position = 'REST'

# Work on the saved mesh and its matching rest skeleton, without adding geometry.
for vertex in body.data.vertices:
    vertex.co = reshape(vertex.co)

# Preserve the weapon's proportions while following its attachment point.
sword_group = sword.vertex_groups[sword.data.vertices[0].groups[0].group].name
anchor = rig.data.bones[sword_group].head_local.copy()
for vertex in sword.data.vertices:
    vertex.co = reshape(anchor) + (vertex.co - anchor) * .82

bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
for bone in rig.data.edit_bones:
    bone.head = reshape(bone.head)
    bone.tail = reshape(bone.tail)
bpy.ops.object.mode_set(mode='OBJECT')
rig.data.pose_position = 'POSE'
rig.animation_data.action = bpy.data.actions['Idle']
bpy.context.scene.frame_set(1)

for image in bpy.data.images:
    if image.type == 'IMAGE' and image.size[0] > 0:
        image.pack()
bpy.ops.object.select_all(action='DESELECT')
for obj in (rig, body, sword):
    obj.select_set(True)
bpy.context.view_layer.objects.active = rig
staging = OUT / 'kael.generated.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(staging), check_existing=False)
staging.replace(OUT / 'kael.blend')
bpy.ops.export_scene.gltf(filepath=str(OUT / 'kael.glb'), export_format='GLB',
    use_selection=True, export_yup=True, export_apply=False, export_skins=True,
    export_def_bones=False, export_animations=True, export_animation_mode='ACTIONS',
    export_merge_animation='ACTION', export_anim_single_armature=True,
    export_extras=True, export_force_sampling=True)
triangles = 0
for obj in (body, sword):
    obj.data.calc_loop_triangles()
    triangles += len(obj.data.loop_triangles)
report = dict(blender=bpy.app.version_string, triangles=triangles,
    source_sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
    glb_sha256=hashlib.sha256((OUT / 'kael.glb').read_bytes()).hexdigest(),
    bones=len(rig.data.bones), animations=[a.name for a in bpy.data.actions],
    status='proportion study; original texture and provisional animation keys',
    enabled_in_game=False)
(OUT / 'kael_manifest.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print('PROPORTION_STUDY', json.dumps(report))
