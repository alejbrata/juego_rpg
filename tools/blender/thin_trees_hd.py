"""Light "far" versions of the HD trees (iteration 1.3 performance pass).

blender --background --factory-startup --python-exit-code 1 --python tools/blender/thin_trees_hd.py -- [--probe] [--only=a,b]

Automatic mesh LOD collapses alpha-tested leaf cards until the canopy vanishes.
Foliage LOD instead removes whole leaf clusters (connected components of the
alpha-clipped surfaces) and enlarges the survivors around their own centre so
the canopy keeps its coverage; bark is decimated normally. Input: the prepared
models/<asset>.glb; output: models/<asset>_far.glb (same origin, scale, materials
and variants), used for the distant tree ring and as shadow casters. Textures are
not exported: Godot reuses the full model's materials by surface name.
"""
import bpy, bmesh, json, math, random, sys, hashlib
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
MODELS = ROOT / 'assets/environments/eclipse_forest_hd/models'
argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
PROBE = '--probe' in argv
ONLY = next((a[7:].split(',') for a in argv if a.startswith('--only=')), None)

# asset: (fraction of leaf clusters kept, bark triangle ratio)
TREES = {
    'island_tree_02': (0.22, 0.25),
    'tree_small_02': (0.22, 0.25),
    'jacaranda_tree': (0.22, 0.25),
}


def tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def alpha_tested(material):
    """glTF alphaMode MASK imports as a linked Alpha input on the Principled BSDF."""
    if not material or not material.use_nodes:
        return False
    for node in material.node_tree.nodes:
        if node.type == 'BSDF_PRINCIPLED' and node.inputs['Alpha'].is_linked:
            return True
    return False


def leaf_slots(obj):
    return {i for i, s in enumerate(obj.material_slots) if alpha_tested(s.material)}


def components(bm, faces):
    """Connected face groups (shared vertices) among the given faces."""
    remaining = set(faces)
    groups = []
    while remaining:
        seed = remaining.pop()
        group, stack = [seed], [seed]
        while stack:
            f = stack.pop()
            for v in f.verts:
                for g in v.link_faces:
                    if g in remaining:
                        remaining.discard(g)
                        group.append(g)
                        stack.append(g)
        groups.append(group)
    return groups


def thin(obj, keep, bark_ratio, rng):
    slots = leaf_slots(obj)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    leaves = [f for f in bm.faces if f.material_index in slots]
    groups = components(bm, leaves)
    info = {'leaf_triangles': sum(len(f.verts) - 2 for f in leaves), 'leaf_clusters': len(groups)}
    if PROBE:
        bm.free()
        return info
    grow = 1.0 / math.sqrt(keep)
    doomed = set()
    for group in groups:
        if rng.random() >= keep:
            doomed.update(group)
            continue
        verts = {v for f in group for v in f.verts}
        centre = sum((v.co for v in verts), Vector()) / len(verts)
        for v in verts:
            v.co = centre + (v.co - centre) * grow
    bmesh.ops.delete(bm, geom=list(doomed), context='FACES')
    bm.to_mesh(obj.data)
    bm.free()
    # Decimate bark only: leaf faces are protected by a vertex group weight of 0.
    bark = [v.index for v in obj.data.vertices]
    leaf_verts = {v for p in obj.data.polygons if p.material_index in slots for v in p.vertices}
    group = obj.vertex_groups.new(name='bark')
    group.add([i for i in bark if i not in leaf_verts], 1.0, 'REPLACE')
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new('Decimate', 'DECIMATE')
    mod.decimate_type = 'COLLAPSE'
    mod.ratio = bark_ratio
    mod.vertex_group = 'bark'
    mod.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.vertex_groups.remove(obj.vertex_groups['bark'])
    info['triangles'] = tris(obj)
    return info


def build(asset, keep, bark_ratio):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(MODELS / (asset + '.glb')))
    rng = random.Random(asset)
    report = {'keep': keep, 'bark_ratio': bark_ratio, 'variants': []}
    for obj in sorted((o for o in bpy.context.scene.objects if o.type == 'MESH'), key=lambda o: o.name):
        source = tris(obj)
        info = thin(obj, keep, bark_ratio, rng)
        info.update(name=obj.name, source_triangles=source)
        report['variants'].append(info)
    if PROBE:
        print('PROBE', asset, json.dumps(report), flush=True)
        return report
    for m in bpy.data.materials:
        if m.blend_method != 'OPAQUE':
            m.blend_method = 'CLIP'
    path = MODELS / (asset + '_far.glb')
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=False, export_animations=False,
                              export_yup=True, export_apply=True, export_image_format='NONE')
    report.update(glb_bytes=path.stat().st_size, glb_sha256=hashlib.sha256(path.read_bytes()).hexdigest())
    print('THINNED', asset, json.dumps(report), flush=True)
    return report


assert bpy.app.background, 'Use a separate background Blender process'
results = {}
for asset, (keep, bark_ratio) in TREES.items():
    if ONLY and asset not in ONLY:
        continue
    results[asset + '_far'] = build(asset, keep, bark_ratio)
if not PROBE:
    manifest = MODELS.parent / 'kit_manifest.json'
    data = json.loads(manifest.read_text(encoding='utf-8'))
    for name, report in results.items():
        data[name] = {'derived_from': name[:-4], 'method': 'leaf-cluster thinning + bark decimation',
                      'variants': [{'name': v['name'], 'source_triangles': v['source_triangles'], 'triangles': v['triangles']}
                                   for v in report['variants']],
                      'glb_bytes': report['glb_bytes'], 'glb_sha256': report['glb_sha256']}
    manifest.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')
