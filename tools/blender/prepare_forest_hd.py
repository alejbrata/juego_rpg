"""Prepare Poly Haven (CC0) scans as game-ready kit pieces for the HD Eclipse Forest.

blender --background --factory-startup --python-exit-code 1 --python tools/blender/prepare_forest_hd.py -- <raw_dir> [--probe] [--only=a,b]

For every asset: import the official glTF, apply transforms, put the origin at the
base centre, scale to the target height, decimate to the triangle budget and export
assets/environments/eclipse_forest_hd/models/<asset>.glb (textures embedded).
The raw downloads are not kept in the repository; sources.json records origin + licence.
"""
import bpy, json, math, sys, hashlib
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/environments/eclipse_forest_hd'
argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
RAW = Path(argv[0])
PROBE = '--probe' in argv
ONLY = next((a[7:].split(',') for a in argv if a.startswith('--only=')), None)

# asset: (target height in metres or None to keep scan scale, triangle budget)
KIT = {
    'island_tree_02': (7.5, 90000),
    'tree_small_02': (6.0, 90000),
    'jacaranda_tree': (7.0, 90000),
    'fern_02': (None, 6232),
    'shrub_02': (None, 14000),
    'shrub_03': (None, 9000),
    'periwinkle_plant': (None, 12000),
    'nettle_plant': (None, 12000),
    'dandelion_01': (None, 8000),
    'rock_moss_set_01': (None, 20000),
    'rock_moss_set_02': (None, 20000),
    'boulder_01': (None, 16000),
    'rock_07': (None, 8000),
    'rock_09': (None, 8000),
    'stone_01': (None, 6000),
    'dead_tree_trunk': (None, 14000),
    'tree_stump_01': (None, 10000),
    'root_cluster_01': (None, 14000),
    'dry_branches_medium_01': (None, 8000),
    'pine_roots': (None, 12000),
    'stone_fire_pit': (None, 3887),
}


def tris(objs):
    return sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs if o.type == 'MESH')


def bounds(objs):
    lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
    for o in objs:
        if o.type != 'MESH':
            continue
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    return lo, hi


def prepare(asset, height, budget):
    """Each mesh object of the scan is a variant (Poly Haven sets ship several
    plants/rocks side by side). Every variant gets its own base-centred origin;
    a common scale keeps their relative sizes. Budget applies per variant."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    src = next((RAW / asset).glob('*.gltf'))
    bpy.ops.import_scene.gltf(filepath=str(src))
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    for o in bpy.context.scene.objects:
        o.select_set(o.type == 'MESH')
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for o in list(bpy.context.scene.objects):
        if o.type != 'MESH':
            bpy.data.objects.remove(o)
    before = tris(meshes)
    info = {'source_triangles': before, 'materials': sorted({s.material.name for o in meshes for s in o.material_slots if s.material}), 'variants': []}
    if PROBE:
        print('PROBE', asset, json.dumps(info))
        return info
    tallest = max(bounds([o])[1].z - bounds([o])[0].z for o in meshes)
    scale = height / tallest if height else 1.0
    meshes.sort(key=lambda o: o.name)
    for i, obj in enumerate(meshes):
        lo, hi = bounds([obj])
        centre = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
        for v in obj.data.vertices:
            v.co = (v.co - centre) * scale
        obj.location = (0, 0, 0)
        obj.name = '%s_%d' % (asset, i)
        n = tris([obj])
        if n > budget:
            bpy.ops.object.select_all(action='DESELECT')
            obj.select_set(True)
            bpy.context.view_layer.objects.active = obj
            mod = obj.modifiers.new('Decimate', 'DECIMATE')
            mod.decimate_type = 'COLLAPSE'
            mod.ratio = budget / n
            mod.use_collapse_triangulate = True
            bpy.ops.object.modifier_apply(modifier=mod.name)
        for poly in obj.data.polygons:
            poly.use_smooth = True
        lo, hi = bounds([obj])
        info['variants'].append({'name': obj.name, 'source_triangles': n, 'triangles': tris([obj]), 'size': [round(x, 3) for x in (hi - lo)]})
    for m in bpy.data.materials:
        if m.blend_method != 'OPAQUE':
            m.blend_method = 'CLIP'
    path = OUT / 'models' / (asset + '.glb')
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=False, export_animations=False,
                              export_yup=True, export_apply=True, export_image_format='JPEG', export_jpeg_quality=88)
    info.update(triangles=tris(meshes), scale=round(scale, 4), glb_bytes=path.stat().st_size,
                glb_sha256=hashlib.sha256(path.read_bytes()).hexdigest())
    print('PREPARED', asset, json.dumps(info), flush=True)
    return info


assert bpy.app.background, 'Use a separate background Blender process'
report = {}
for asset, (height, budget) in KIT.items():
    if ONLY and asset not in ONLY:
        continue
    report[asset] = prepare(asset, height, budget)
if not PROBE:
    manifest = OUT / 'kit_manifest.json'
    old = json.loads(manifest.read_text(encoding='utf-8')) if manifest.exists() else {}
    old = {k: v for k, v in old.items() if 'variants' in v}
    old.update(report)
    manifest.write_text(json.dumps(old, indent=2) + '\n', encoding='utf-8')
