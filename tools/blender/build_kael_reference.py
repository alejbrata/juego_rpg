"""Build/export the isolated reference study; never overwrite Kael 0.9.

blender --background --factory-startup --python-exit-code 1 --python tools/blender/build_kael_reference.py
Add -- --export-only to re-export the saved study after manual Blender edits.
"""
import hashlib
import json
import struct
import sys
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/characters/kael/reference_study'
sys.path.insert(0, str(Path(__file__).resolve().parent))
import kael_reference_mesh as art

CLIPS = ('Idle', 'Walk', 'Attack', 'Hurt', 'Defend', 'KO')


def adjust_rig(rig):
    bones = {
        'root': ((0,0,0),(0,0,.15)),
        'pelvis': ((0,0,.99),(0,0,1.12)),
        'spine': ((0,0,1.12),(0,0,1.49)),
        'neck': ((0,0,1.49),(0,0,1.61)),
        'head': ((0,0,1.61),(0,0,1.84)),
    }
    for sign, side in ((-1,'L'),(1,'R')):
        def p(x,y,z): return (sign*x,y,z)
        bones.update({
            'upper_arm.'+side: (p(.208,0,1.48),p(.304,-.020,1.23)),
            'forearm.'+side: (p(.304,-.020,1.23),p(.356,-.060,1.035)),
            'hand.'+side: (p(.356,-.060,1.035),p(.366,-.079,.93)),
            'thigh.'+side: (p(.106,0,1.025),p(.122,-.012,.60)),
            'calf.'+side: (p(.122,-.012,.60),p(.120,.002,.18)),
            'foot.'+side: (p(.120,.002,.18),p(.120,-.15,.06)),
        })
    bpy.context.view_layer.objects.active=rig
    bpy.ops.object.mode_set(mode='EDIT')
    for name,(head,tail) in bones.items():
        bone=rig.data.edit_bones[name]
        bone.head=head; bone.tail=tail
    bpy.ops.object.mode_set(mode='OBJECT')


def export():
    rig=bpy.data.objects['KaelRig']
    objects=[rig,bpy.data.objects['KaelBody'],bpy.data.objects['KaelSword']]
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects: obj.select_set(True)
    bpy.context.view_layer.objects.active=rig
    for name in CLIPS:
        assert bpy.data.actions.get(name), name
    for obj in objects[1:]:
        for vertex in obj.data.vertices:
            assert 0 < len(vertex.groups) <= 4
            assert abs(sum(g.weight for g in vertex.groups)-1) < .001
    bpy.ops.export_scene.gltf(filepath=str(OUT/'kael.glb'), export_format='GLB',
        use_selection=True, export_yup=True, export_apply=False, export_skins=True,
        export_def_bones=False, export_animations=True, export_animation_mode='ACTIONS',
        export_merge_animation='ACTION', export_anim_single_armature=True,
        export_extras=True, export_force_sampling=True)
    blob=(OUT/'kael.glb').read_bytes()
    length,kind=struct.unpack_from('<II',blob,12)
    assert kind==0x4E4F534A
    gltf=json.loads(blob[20:20+length])
    assert all('uri' not in item for item in gltf['buffers']+gltf.get('images',[]))
    primitives=[p for mesh in gltf['meshes'] for p in mesh['primitives']]
    triangles=sum(gltf['accessors'][p['indices']]['count']//3 for p in primitives)
    def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
    report={
        'art_revision':'reference-study', 'blender':bpy.app.version_string,
        'source':'Original locally scripted mesh following user-supplied Kael turnaround',
        'texture_method':'Algorithmically painted atlas; no external generation service',
        'glb_bytes':len(blob), 'triangles':triangles,
        'exported_vertices':sum(gltf['accessors'][p['attributes']['POSITION']]['count'] for p in primitives),
        'author_vertices':sum(len(o.data.vertices) for o in objects[1:]),
        'bones':len(rig.data.bones), 'animations':[a['name'] for a in gltf['animations']],
        'animation_origin':'Provisional 0.8 clips retargeted through revised rest skeleton',
        'materials':len(gltf['materials']), 'surfaces':len(primitives),
        'textures': [{'width':int(i.size[0]),'height':int(i.size[1])} for i in bpy.data.images if i.name=='KaelReferenceAtlas'],
        'authored_sections':sum(int(o.get('authored_sections',0)) for o in objects[1:]),
        'glb_sha256':sha(OUT/'kael.glb'), 'blend_sha256':sha(OUT/'kael.blend'),
        'atlas_sha256':sha(OUT/'kael_atlas.png'),
        'mesh_script_sha256':sha(Path(art.__file__)), 'build_script_sha256':sha(Path(__file__)),
        'base_animation_source_sha256':sha(ROOT/'assets/characters/kael/v08/kael.blend'),
        'mobile_performance_measured':False,
    }
    (OUT/'kael_manifest.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print('KAEL_REFERENCE',json.dumps(report))


if not bpy.app.background:
    raise RuntimeError('Use a separate --background --factory-startup process')
OUT.mkdir(parents=True,exist_ok=True)
if '--export-only' in sys.argv:
    bpy.ops.wm.open_mainfile(filepath=str(OUT/'kael.blend'))
else:
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets/characters/kael/v08/kael.blend'))
    rig=bpy.data.objects['KaelRig']
    rig.animation_data.action=None
    for obj in list(bpy.data.objects):
        if obj != rig: bpy.data.objects.remove(obj,do_unlink=True)
    for data in (bpy.data.meshes,bpy.data.materials,bpy.data.images):
        for item in list(data):
            if item.users==0: data.remove(item)
    adjust_rig(rig)
    mats=art.materials(OUT)
    body,blade=art.build()
    body.object('KaelBody',rig,mats)
    blade.object('KaelSword',rig,mats)
    rig.animation_data.action=bpy.data.actions['Idle']
    bpy.context.scene.frame_set(1)
    bpy.context.scene.render.fps=30
    staging=OUT/'kael.generated.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(staging),check_existing=False)
    staging.replace(OUT/'kael.blend')
export()
