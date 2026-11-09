"""Edit the saved polished Kael into a cleaner retro JRPG interpretation.

No mesh generator is invoked. Faces, UV layout, weights and rig are preserved.
--export-only exports the saved retro source without repeating the edits.
"""
import bpy
import hashlib
import json
import math
import struct
import sys
from pathlib import Path
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'assets/characters/kael/polished'
OUT=ROOT/'assets/characters/kael/retro'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def components(mesh):
    neighbors=[[] for _ in mesh.vertices]
    for edge in mesh.edges:
        a,b=edge.vertices; neighbors[a].append(b); neighbors[b].append(a)
    seen=set(); result=[]
    for vertex in mesh.vertices:
        if vertex.index in seen: continue
        todo=[vertex.index]; seen.add(vertex.index); ids=[]
        while todo:
            i=todo.pop(); ids.append(i)
            for j in neighbors[i]:
                if j not in seen: seen.add(j); todo.append(j)
        result.append(sorted(ids))
    return result


def palette_tiles(mesh):
    tiles={}
    for face in mesh.polygons:
        uv=mesh.uv_layers.active.data[face.loop_indices[0]].uv
        tile=int(uv.x*4)+int(uv.y*4)*4
        for index in face.vertices: tiles.setdefault(index,set()).add(tile)
    return tiles


def head_shape(point):
    # Work in the reference's proportions, then return to the saved asset scale.
    x,y,z=point.x/1.18,point.y/1.18,point.z/1.18+.018
    if z<1.735: z=1.735+(z-1.735)*.86
    return Vector((x*1.20*1.18,y*1.10*1.18,(1.735+(z-1.735)*1.16-.018)*1.18-.030))


def edit_mesh(rig,body,sword):
    rig.animation_data.action=None
    for bone in rig.pose.bones: bone.matrix_basis.identity()
    mesh=body.data; parts=components(mesh); tiles=palette_tiles(mesh)
    head_index=body.vertex_groups['head'].index
    head_ids={v.index for v in mesh.vertices if any(g.group==head_index and g.weight>.99 for g in v.groups)}
    original=[v.co.copy() for v in mesh.vertices]
    head_part=next(ids for ids in parts if len(ids)==720 and ids[0] in head_ids)
    assert len(mesh.vertices)==7804 and len(head_part)==720, 'Source topology changed: inspect before restyling'
    for v in mesh.vertices:
        if v.index in head_ids:
            p=v.co.copy()
            # Simplify the strong nasal ridge, retaining the original face mesh.
            if v.index in head_part and p.y<-.045:
                x,z=p.x/1.18,p.z/1.18+.018
                p.y+=1.18*(.006*math.exp(-(x/.016)**2-((z-1.714)/.045)**2)+.010*math.exp(-(x/.020)**2-((z-1.688)/.022)**2))
            v.co=head_shape(p)
        elif 1.1<v.co.z<1.80:
            # Add volume around the existing limbs/rig rather than moving joints.
            if abs(v.co.x)<.26:
                v.co.x*=1.06
                v.co.y*=1.025
    # Preserve the neck seam after the shorter lower face.
    for v in mesh.vertices:
        if v.index not in head_ids and any(g.group==head_index for g in v.groups):
            weight=next(g.weight for g in v.groups if g.group==head_index)
            v.co=v.co.lerp(head_shape(original[v.index]),weight)

    # Existing face polygons are the projection target, not a newly built head.
    face_set=set(head_part)
    faces=[tuple(p.vertices) for p in mesh.polygons if set(p.vertices).issubset(face_set)]
    bvh=BVHTree.FromPolygons([v.co for v in mesh.vertices],faces,all_triangles=False)
    def project(v,layer):
        hit=bvh.ray_cast(Vector((v.co.x,-1,v.co.z)),Vector((0,1,0)),2)[0]
        if hit is not None: v.co.y=hit.y-layer
    features={}
    for ids in parts:
        if ids[0] not in head_ids or ids==head_part: continue
        tile=next(iter(tiles[ids[0]]))
        p=original[ids[0]]
        n=len(ids)
        kind=None
        if tile==11 and n==9: kind='white'
        elif tile==12 and n==17: kind='iris'
        elif tile==13 and n==17: kind='pupil'
        elif tile==11 and n==3: kind='spark'
        elif tile in (8,15) and n==20 and 2.0<p.z<2.05: kind='lid'
        elif tile==8 and n==8 and p.z>2.04: kind='brow'
        elif tile==15 and n==25: kind='mouth'
        elif tile==0 and n==12 and p.z<1.94: kind='lower_lip'
        elif tile==15 and n==8 and 1.95<p.z<1.98: kind='nostril'
        if kind is None: continue
        sign=1 if p.x>0 else -1
        center=head_shape(Vector((sign*.037*1.18,-.073*1.18,(1.735-.018)*1.18)))
        for i in ids:
            v=mesh.vertices[i]
            if kind in ('white','iris','pupil','spark','lid'):
                v.co.x=center.x+(v.co.x-center.x)*(1.08 if kind in ('white','lid') else 1.60)
                v.co.z=center.z+(v.co.z-center.z)*(1.65 if kind in ('white','lid') else 1.60)
                if kind in ('white','lid') and v.co.z>center.z:
                    v.co.z-=.004*max(0,1-(abs(v.co.x)-.018)/.06)
                layer={'white':.0018,'iris':.0029,'pupil':.0038,'spark':.0045,'lid':.0026}[kind]
                project(v,layer)
            elif kind=='brow':
                # A thick, nearly straight brow, low at the inner corner.
                pair=ids[(ids.index(i)//2)*2:(ids.index(i)//2)*2+2]
                pair_center=sum(head_shape(original[j]).z for j in pair)/2
                v.co.z=center.z+.030+.10*(abs(v.co.x)-.03)+(v.co.z-pair_center)*1.45
                project(v,.0030)
            elif kind=='mouth':
                center_z=head_shape(Vector((0,-.08*1.18,(1.649-.018)*1.18))).z
                v.co.z=center_z+(v.co.z-center_z)*2.5+.006
                v.co.x*=.86
                project(v,.0018)
            elif kind=='lower_lip':
                v.co.z+=.006
                project(v,.0008)
            elif kind=='nostril':
                project(v,.0010)
        features.setdefault(kind,[]).extend(ids)
    # Dark, clean upper lids/brows and a restrained mouth, using existing atlas.
    remap=set(features.get('brow',[])+features.get('lid',[])+features.get('mouth',[]))
    for face in mesh.polygons:
        if face.vertices[0] not in remap: continue
        for loop in face.loop_indices:
            uv=mesh.uv_layers.active.data[loop].uv
            uv.x=(1+(uv.x*4)%1)/4; uv.y=(3+(uv.y*4)%1)/4  # Ink
    mesh.update()
    return {'head_width_factor':1.20,'eye_opening_factor':1.65,
            'edited_features':{key:len(value) for key,value in features.items()}}


def clean_atlas():
    old=bpy.data.images['KaelReferenceAtlas']
    w,h=old.size; rgba=np.empty(w*h*4,dtype=np.float32)
    old.pixels.foreach_get(rgba); rgba=rgba.reshape(h,w,4)
    # The polished PNG is already sRGB. Filter within tiles and reduce fine
    # contrast; do not apply the previous linear/sRGB repair a second time.
    tile=w//4
    for i in range(16):
        row,col=divmod(i,4)
        region=rgba[row*tile:(row+1)*tile,col*tile:(col+1)*tile,:3]
        if i in (0,1,11,12,13,15): continue
        sample=region.copy()
        # Box filter with edge padding, so colors never bleed across atlas tiles.
        padded=np.pad(sample,((4,4),(4,4),(0,0)),mode='edge')
        smooth=sum(padded[dy:dy+tile,dx:dx+tile] for dy in range(9) for dx in range(9))/81
        mean=sample.mean(axis=(0,1))
        region[:]=mean+(smooth-mean)*(.35 if i in (8,9) else .55)
    # Restrained warm hair and a deeper main coat, separated from blue lapels.
    for i,factor in [(2,(.78,.83,.93)),(3,(.90,.97,1.04)),(8,(.80,.72,.66)),(9,(.80,.73,.66)),(6,(.90,.94,1.0)),(7,(.91,.91,.92))]:
        row,col=divmod(i,4)
        rgba[row*tile:(row+1)*tile,col*tile:(col+1)*tile,:3]*=factor
    rgba=np.clip(rgba,0,1)
    old.pixels.foreach_set(rgba.ravel())
    old.filepath_raw=str(OUT/'kael_atlas.png'); old.file_format='PNG'; old.save()
    revised=bpy.data.images.load(str(OUT/'kael_atlas.png'),check_existing=False)
    revised.pack(); revised.filepath_raw='//kael_atlas.png'
    for material in bpy.data.materials:
        for node in material.node_tree.nodes:
            if node.type=='TEX_IMAGE' and node.image==old: node.image=revised
        shader=next(n for n in material.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
        if material.name=='KaelMetal':
            shader.inputs['Metallic'].default_value=.30
            shader.inputs['Roughness'].default_value=.65
            shader.inputs['Specular IOR Level'].default_value=.22
    bpy.data.images.remove(old); revised.name='KaelReferenceAtlas'


def keep_ground_contact(rig,objects):
    checks={}
    for action in bpy.data.actions:
        rig.animation_data.action=action
        first,last=map(int,action.frame_range)
        minima=[]
        for frame in range(first,last+1):
            bpy.context.scene.frame_set(frame)
            bpy.context.view_layer.update()
            deps=bpy.context.evaluated_depsgraph_get()
            z=100
            for obj in objects:
                evaluated=obj.evaluated_get(deps); mesh=evaluated.to_mesh()
                z=min(z,min((evaluated.matrix_world @ v.co).z for v in mesh.vertices))
                evaluated.to_mesh_clear()
            # The larger head changes KO's contact. Preserve all other poses.
            if action.name=='KO' or z<.006:
                matrix=rig.pose.bones['root'].matrix.copy(); matrix.translation.z+=.006-z
                rig.pose.bones['root'].matrix=matrix
                rig.pose.bones['root'].keyframe_insert('location',frame=frame,group='root')
                z=.006
            minima.append(z)
        checks[action.name]={'seconds':(last-first)/bpy.context.scene.render.fps,'min_vertex_z':min(minima)}
    rig.animation_data.action=bpy.data.actions['Idle']; bpy.context.scene.frame_set(1)
    return checks


def export(rig,objects,style,checks):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in [rig]+objects: obj.select_set(True)
    bpy.context.view_layer.objects.active=rig
    bpy.ops.export_scene.gltf(filepath=str(OUT/'kael.glb'),export_format='GLB',use_selection=True,
        export_yup=True,export_apply=False,export_skins=True,export_def_bones=False,
        export_animations=True,export_animation_mode='ACTIONS',export_merge_animation='ACTION',
        export_anim_single_armature=True,export_extras=True,export_force_sampling=True)
    blob=(OUT/'kael.glb').read_bytes(); length=struct.unpack_from('<I',blob,12)[0]
    gltf=json.loads(blob[20:20+length]); primitives=[p for m in gltf['meshes'] for p in m['primitives']]
    assert all('uri' not in item for item in gltf['buffers']+gltf['images'])
    report=json.loads((SOURCE/'kael_manifest.json').read_text(encoding='utf-8'))
    report.pop('polish_script_sha256',None)
    report.update({'art_revision':'retro','blender':bpy.app.version_string,
        'source_blend_sha256':sha(SOURCE/'kael.blend'),'source_glb_sha256':sha(SOURCE/'kael.glb'),
        'blend_sha256':sha(OUT/'kael.blend'),'glb_sha256':sha(OUT/'kael.glb'),
        'atlas_sha256':sha(OUT/'kael_atlas.png'),'style_script_sha256':sha(Path(__file__)),
        'triangles':sum(gltf['accessors'][p['indices']]['count']//3 for p in primitives),
        'exported_vertices':sum(gltf['accessors'][p['attributes']['POSITION']]['count'] for p in primitives),
        'author_vertices':sum(len(o.data.vertices) for o in objects),'surfaces':len(primitives),
        'materials':len(gltf['materials']),'bones':len(rig.data.bones),'glb_bytes':len(blob),
        'animations':[a['name'] for a in gltf['animations']],'animation_checks':checks,'style':style})
    (OUT/'kael_manifest.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print('RETRO_KAEL',json.dumps(report))


if not bpy.app.background: raise RuntimeError('Use a separate background process')
OUT.mkdir(parents=True,exist_ok=True)
only='--export-only' in sys.argv
bpy.ops.wm.open_mainfile(filepath=str((OUT if only else SOURCE)/'kael.blend'))
rig=bpy.data.objects['KaelRig']; objects=[bpy.data.objects['KaelBody'],bpy.data.objects['KaelSword']]
if only:
    previous=json.loads((OUT/'kael_manifest.json').read_text(encoding='utf-8'))
    style=previous['style']; checks=previous['animation_checks']
else:
    style=edit_mesh(rig,*objects); clean_atlas(); checks=keep_ground_contact(rig,objects)
    staging=OUT/'kael.generated.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(staging),check_existing=False)
    staging.replace(OUT/'kael.blend')
export(rig,objects,style,checks)
