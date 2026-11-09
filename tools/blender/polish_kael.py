"""Polish the SAVED reference-study asset. Never calls a mesh generator.

Run with Blender --background --factory-startup --python-exit-code 1 --python
tools/blender/polish_kael.py. -- --export-only exports saved polished edits.
Original meshes, UVs and topology remain in reference_study/ for comparison.
"""
import hashlib
import json
import math
import struct
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Vector, Euler

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'assets/characters/kael/reference_study'
OUT=ROOT/'assets/characters/kael/polished'
SCALE=1.18
FPS=60
GROUND_CLEARANCE=.006  # Leaves margin for quaternion interpolation in Godot.
CLIPS={'Idle':180,'Walk':36,'Attack':48,'Hurt':24,'Defend':24,'KO':60}
WALK_STRIDE=1.0
WALK_SPEED=WALK_STRIDE/(CLIPS['Walk']/FPS/2)


def smooth(t):
    t=max(0,min(1,t))
    return t*t*(3-2*t)


def reshape(p):
    x,y,z=p
    torso=1-smooth((z-1.46)/.12)
    return Vector((x*SCALE*(1+.08*torso),y*SCALE*(1+.04*torso),(z-.018)*SCALE))


def polish_mesh(rig,objects):
    rig.animation_data.action=None
    for bone in rig.pose.bones: bone.matrix_basis=Matrix.Identity(4)
    for obj in objects:
        for vertex in obj.data.vertices: vertex.co=reshape(vertex.co)
    bpy.context.view_layer.objects.active=rig
    bpy.ops.object.mode_set(mode='EDIT')
    for bone in rig.data.edit_bones:
        bone.head=reshape(bone.head); bone.tail=reshape(bone.tail)
    bpy.ops.object.mode_set(mode='OBJECT')


def polish_atlas():
    image=bpy.data.images['KaelReferenceAtlas']
    width,height=image.size
    array=np.empty(width*height*4,dtype=np.float32)
    image.pixels.foreach_get(array)
    array=array.reshape(height,width,4)
    # The saved reference PNG contains linear palette values in an sRGB image.
    # Retint that data, then encode sRGB once for an actual color texture.
    swatches=[('d9bba3','d9bba3'),('cfad90','cfad90'),('354b72','425e86'),('526c95','617da4'),
              ('795541','866044'),('423932','534435'),('abb9c7','abb9c7'),('c9a571','c9a571'),
              ('483029','51392b'),('634432','72513b'),('343740','40444f'),('ddd6ca','ddd6ca'),
              ('946241','946241'),('241d20','241d20'),('328bcb','54abe4'),('a37061','a37061')]
    def linear(color):
        c=np.array([int(color[i:i+2],16)/255 for i in (0,2,4)])
        return np.where(c<=.04045,c/12.92,((c+.055)/1.055)**2.4)
    tile=width//4
    for i,(old,new) in enumerate(swatches):
        row,col=divmod(i,4)
        region=array[row*tile:(row+1)*tile,col*tile:(col+1)*tile,:3]
        region[:]=np.clip(region*linear(new)/linear(old),0,1)
    rgb=array[:,:,:3]
    array[:,:,:3]=np.where(rgb<=.0031308,rgb*12.92,1.055*np.maximum(rgb,0)**(1/2.4)-.055)
    image.pixels.foreach_set(array.ravel())
    image.filepath_raw=str(OUT/'kael_atlas.png'); image.file_format='PNG'; image.save()
    # Repacking an already packed source can retain its old PNG bytes. Load the
    # saved file as a fresh datablock so GLB and .blend embed the revised atlas.
    revised=bpy.data.images.load(str(OUT/'kael_atlas.png'),check_existing=False)
    revised.pack(); revised.filepath_raw='//kael_atlas.png'
    for m in bpy.data.materials:
        for node in m.node_tree.nodes:
            if node.type=='TEX_IMAGE' and node.image==image: node.image=revised
        shader=next((n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
        if shader is None: continue
        if m.name=='KaelMetal':
            shader.inputs['Metallic'].default_value=.40
            shader.inputs['Roughness'].default_value=.48
        elif m.name=='KaelClothSkin':
            shader.inputs['Roughness'].default_value=.86
            shader.inputs['Specular IOR Level'].default_value=.28
        elif m.name=='KaelCrystal':
            shader.inputs['Emission Strength'].default_value=.22
    bpy.data.images.remove(image)
    revised.name='KaelReferenceAtlas'


def rotations(rig,poses):
    for name,angles in poses.items():
        rig.pose.bones[name].rotation_quaternion=Euler(angles,'XYZ').to_quaternion()


def offset(rig,name,world):
    # Convert a displacement in armature space into this bone's rest axes.
    rig.pose.bones[name].location=rig.data.bones[name].matrix_local.to_3x3().inverted() @ Vector(world)


def aim_bone(rig,name,head,tail):
    bone=rig.data.bones[name]
    rotation=(bone.tail_local-bone.head_local).normalized().rotation_difference((tail-head).normalized())
    matrix=(rotation.to_matrix() @ bone.matrix_local.to_3x3()).to_4x4()
    matrix.translation=head
    rig.pose.bones[name].matrix=matrix
    bpy.context.view_layer.update()


def leg_ik(rig,side,ankle):
    """Bake a two-link leg into FK keys; no runtime IK or dependencies."""
    upper=rig.pose.bones['thigh.'+side]
    hip=upper.head.copy()
    thigh=rig.data.bones['thigh.'+side].length
    calf=rig.data.bones['calf.'+side].length
    delta=ankle-hip; distance=min(delta.length,thigh+calf-.0001)
    axis=delta.normalized()
    projected=(thigh*thigh-calf*calf+distance*distance)/(2*distance)
    bend=Vector((0,-1,0))-axis*axis.dot(Vector((0,-1,0)))
    bend.normalize()
    knee=hip+axis*projected+bend*math.sqrt(max(0,thigh*thigh-projected*projected))
    aim_bone(rig,'thigh.'+side,hip,knee)
    aim_bone(rig,'calf.'+side,knee,ankle)
    foot=rig.data.bones['foot.'+side]
    matrix=foot.matrix_local.copy(); matrix.translation=ankle
    rig.pose.bones['foot.'+side].matrix=matrix
    bpy.context.view_layer.update()


def base_pose(rig,breath=0):
    rotations(rig,{
        'spine':(.018+breath*.009,0,-.025),'head':(-.012-breath*.004,.025,0),
        'upper_arm.L':(-.06,0,.06),'forearm.L':(-.12,0,0),
        'upper_arm.R':(-.15,0,-.04),'forearm.R':(-.18,0,0),
        'hand.R':(.06,0,.06),
    })
    # Breathing comes from chest volume, not lifting planted feet.
    rig.pose.bones['spine'].scale=Vector((1+breath*.004,1,1+breath*.006))


def arm_ik(rig,side,wrist,blade_angle):
    """Bake an outside elbow arc; keep the sword on its side of the torso."""
    upper=rig.pose.bones['upper_arm.'+side]
    shoulder=upper.head.copy()
    a=rig.data.bones['upper_arm.'+side].length
    b=rig.data.bones['forearm.'+side].length
    delta=wrist-shoulder
    distance=min(delta.length,a+b-.001)
    axis=delta.normalized(); wrist=shoulder+axis*distance
    projected=(a*a-b*b+distance*distance)/(2*distance)
    bend=Vector((1 if side=='R' else -1,0,-.2))
    bend=(bend-axis*axis.dot(bend)).normalized()
    elbow=shoulder+axis*projected+bend*math.sqrt(max(0,a*a-projected*projected))
    aim_bone(rig,'upper_arm.'+side,shoulder,elbow)
    aim_bone(rig,'forearm.'+side,elbow,wrist)
    hand=rig.data.bones['hand.'+side]
    matrix=(Matrix.Rotation(blade_angle,3,'X') @ hand.matrix_local.to_3x3()).to_4x4()
    matrix.translation=wrist
    rig.pose.bones['hand.'+side].matrix=matrix
    bpy.context.view_layer.update()


def interpolate_keys(t,keys):
    for (a,x),(b,y) in zip(keys,keys[1:]):
        if t<=b:
            u=smooth((t-a)/(b-a)); return [v*(1-u)+w*u for v,w in zip(x,y)]
    return keys[-1][1]


def pose_frame(rig,clip,t):
    for b in rig.pose.bones:
        b.rotation_mode='QUATERNION'; b.matrix_basis=Matrix.Identity(4)
    base_pose(rig,math.sin(t*math.tau) if clip=='Idle' else 0)
    bpy.context.view_layer.update()
    if clip=='Idle':
        rig.pose.bones['forearm.R'].rotation_quaternion=Euler((-.18+.012*math.sin(t*math.tau),0,0)).to_quaternion()
    elif clip=='Walk':
        phase=t*math.tau
        offset(rig,'pelvis',(0,0,-.14+.012*math.cos(phase*2)))
        rotations(rig,{'spine':(.035,.025*math.sin(phase),0),
            'upper_arm.L':(.28*math.cos(phase),0,.05),'forearm.L':(-.20,0,0),
            'upper_arm.R':(-.10-.12*math.cos(phase),0,-.06),'forearm.R':(-.20,0,0)})
        bpy.context.view_layer.update()
        for side,shift in [('L',0),('R',.5)]:
            q=(t+shift)%1
            if q<.5:
                y=-WALK_STRIDE/2+WALK_STRIDE*q*2; lift=0
            else:
                u=(q-.5)*2
                y=WALK_STRIDE/2-WALK_STRIDE*smooth(u)
                lift=.14*math.sin(math.pi*u)
            ankle=rig.data.bones['foot.'+side].head_local.copy()
            ankle.y+=y; ankle.z+=lift
            leg_ik(rig,side,ankle)
    elif clip=='Attack':
        # Lift beside the head, cut forward/down, recover. Explicit wrist and
        # blade arcs avoid the old local-axis pose that merely waved the sword.
        start=rig.pose.bones['hand.R'].head.copy()
        a=interpolate_keys(t,[(0,[*start,0]),(.30,[.62,.02,1.85,-.65]),
            (.56,[.53,-.43,1.40,1.95]),(.72,[.55,-.30,1.24,1.65]),(1,[*start,0])])
        arm_ik(rig,'R',Vector(a[:3]),a[3])
    elif clip=='Hurt':
        hit=interpolate_keys(t,[(0,[0]),(.20,[1]),(.55,[.38]),(1,[0])])[0]
        rotations(rig,{'spine':(-.20*hit,.06*hit,0),'head':(.12*hit,0,0),
            'upper_arm.L':(-.06+.14*hit,0,.06),'forearm.R':(-.18-.12*hit,0,0)})
    elif clip=='Defend':
        u=smooth(min(1,t/.65))
        for side,target in [('R',Vector((.43,-.32,1.48))),('L',Vector((-.12,-.30,1.45)))]:
            start=rig.pose.bones['hand.'+side].head.copy()
            arm_ik(rig,side,start.lerp(target,u),.12*u)
    elif clip=='KO':
        u=smooth(t)
        # Fold knees/back first; then settle on the ground, not a rigid plank.
        rotations(rig,{'root':(-math.pi*.49*u,0,.10*u),
            'spine':(.10*math.sin(math.pi*t),0,0),'head':(.14*u,0,0),
            'thigh.L':(-.22*u,0,0),'calf.L':(.45*u,0,0),'foot.L':(-.20*u,0,0),
            'upper_arm.L':(-.06+.15*u,0,.06+.35*u),
            'upper_arm.R':(-.15+.25*u,0,-.04-.35*u),'forearm.R':(-.18,0,0)})
        offset(rig,'root',(0,0,.22*u))
    bpy.context.view_layer.update()


def mesh_min_z(objects):
    deps=bpy.context.evaluated_depsgraph_get()
    minimum=1000
    for obj in objects:
        evaluated=obj.evaluated_get(deps)
        mesh=evaluated.to_mesh()
        minimum=min(minimum,min((evaluated.matrix_world @ v.co).z for v in mesh.vertices))
        evaluated.to_mesh_clear()
    return minimum


def animate(rig,objects):
    rig.animation_data_clear()
    for action in list(bpy.data.actions): bpy.data.actions.remove(action)
    measurements={}
    for clip,count in CLIPS.items():
        action=bpy.data.actions.new(clip); action.use_fake_user=True
        rig.animation_data_create(); rig.animation_data.action=action
        minima=[]
        for i in range(count+1):
            frame=i+1
            bpy.context.scene.frame_set(frame)
            pose_frame(rig,clip,i/count)
            z=mesh_min_z(objects)
            if z<GROUND_CLEARANCE or clip=='KO':
                # Bake ground clearance into the animation; no per-frame mesh
                # scans or floor correction are required by the game runtime.
                delta=GROUND_CLEARANCE-z
                matrix=rig.pose.bones['root'].matrix.copy()
                matrix.translation.z+=delta
                rig.pose.bones['root'].matrix=matrix
                bpy.context.view_layer.update()
            minima.append(mesh_min_z(objects))
            for bone in rig.pose.bones:
                bone.keyframe_insert('location',frame=frame,group=bone.name)
                bone.keyframe_insert('rotation_quaternion',frame=frame,group=bone.name)
                bone.keyframe_insert('scale',frame=frame,group=bone.name)
        # Dense 60 Hz baked keys use linear interpolation to avoid overshooting
        # the ground or weapon trajectory between authored samples.
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        for key in curve.keyframe_points: key.interpolation='LINEAR'
        measurements[clip]={'seconds':count/FPS,'min_vertex_z':min(minima),'max_min_vertex_z':max(minima)}
    rig.animation_data.action=bpy.data.actions['Idle']; bpy.context.scene.frame_set(1)
    return measurements


def export(rig,objects,measurements):
    bpy.ops.object.select_all(action='DESELECT')
    for o in [rig]+objects: o.select_set(True)
    bpy.context.view_layer.objects.active=rig
    bpy.ops.export_scene.gltf(filepath=str(OUT/'kael.glb'),export_format='GLB',use_selection=True,
        export_yup=True,export_apply=False,export_skins=True,export_def_bones=False,
        export_animations=True,export_animation_mode='ACTIONS',export_merge_animation='ACTION',
        export_anim_single_armature=True,export_extras=True,export_force_sampling=True)
    blob=(OUT/'kael.glb').read_bytes(); length=struct.unpack_from('<I',blob,12)[0]
    gltf=json.loads(blob[20:20+length])
    primitives=[p for mesh in gltf['meshes'] for p in mesh['primitives']]
    assert all('uri' not in o for o in gltf['buffers']+gltf['images'])
    def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
    report={'art_revision':'polished','blender':bpy.app.version_string,
        'source_blend_sha256':sha(SOURCE/'kael.blend'),'source_glb_sha256':sha(SOURCE/'kael.glb'),
        'blend_sha256':sha(OUT/'kael.blend'),'glb_sha256':sha(OUT/'kael.glb'),
        'atlas_sha256':sha(OUT/'kael_atlas.png'),'polish_script_sha256':sha(Path(__file__)),
        'triangles':sum(gltf['accessors'][p['indices']]['count']//3 for p in primitives),
        'exported_vertices':sum(gltf['accessors'][p['attributes']['POSITION']]['count'] for p in primitives),
        'author_vertices':sum(len(o.data.vertices) for o in objects),'surfaces':len(primitives),
        'materials':len(gltf['materials']),'bones':len(rig.data.bones),'glb_bytes':len(blob),
        'animations':[a['name'] for a in gltf['animations']],'animation_checks':measurements,
        'authored_sections':sum(int(o.get('authored_sections',0)) for o in objects),
        'walk_reference_speed':WALK_SPEED,'locomotion_blend':.12,'lunge_distance':0.0,
        'presentation_durations':{'Attack':.80,'Hurt':.40,'Defend':.40,'KO':1.0},
        'baked_uniform_scale':SCALE,'texture_size':[1024,1024],'mobile_tested':False}
    (OUT/'kael_manifest.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print('POLISHED_KAEL',json.dumps(report))


if not bpy.app.background: raise RuntimeError('Use a separate background Blender process')
OUT.mkdir(parents=True,exist_ok=True)
if '--export-only' in sys.argv:
    bpy.ops.wm.open_mainfile(filepath=str(OUT/'kael.blend'))
    checks=json.loads((OUT/'kael_manifest.json').read_text(encoding='utf-8'))['animation_checks']
else:
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE/'kael.blend'))
rig=bpy.data.objects['KaelRig']; objects=[bpy.data.objects['KaelBody'],bpy.data.objects['KaelSword']]
if '--export-only' not in sys.argv:
    polish_mesh(rig,objects); polish_atlas()
    bpy.context.scene.render.fps=FPS
    checks=animate(rig,objects)
    staging=OUT/'kael.generated.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(staging),check_existing=False)
    staging.replace(OUT/'kael.blend')
export(rig,objects,checks)
