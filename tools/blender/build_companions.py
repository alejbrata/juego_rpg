"""Original Lyra/Nira garment meshes, independent of Kael's character geometry.

Reuses only the proven contour/UV surface-writing helper. Blender background CLI.
-- --export-only preserves saved manual edits. --hero lyra|nira limits the build.
"""
import bpy
import math
import json
import sys
import struct
import hashlib
from pathlib import Path
import numpy as np
from mathutils import Vector, Matrix, Euler

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(Path(__file__).resolve().parent))
import kael_reference_mesh as surface_tools
Surface=surface_tools.Surface
FPS=60
PALETTES={
 'lyra':['e1bda9','d6ae98','3e466e','7c689f','6e5362','3d354e','b5c4da','b1afcf','30283e','59466d','34374e','ede8dc','718eae','241e30','91c9ec','9d6665'],
 'nira':['e3bfa0','d9b18f','6e8e75','d7cfaf','a07950','64503b','b4beaa','c6a76c','855035','af7650','58634e','f1e8d1','87945f','302a28','b9dda1','a3685a'],
}
CONFIG={
 'lyra':dict(hip=1.10,waist=1.24,shoulder=1.66,neck=1.79,chin=1.80,top=2.14,sx=.225,elbow=.315,wrist=.365,knee=.64,legx=.125,width=.187),
 'nira':dict(hip=1.035,waist=1.17,shoulder=1.56,neck=1.68,chin=1.69,top=2.035,sx=.252,elbow=.345,wrist=.395,knee=.60,legx=.145,width=.218),
}

def smooth(t):
    t=max(0,min(1,t));return t*t*(3-2*t)

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()

def materials(hero,out):
    image=bpy.data.images.new(hero.title()+'Atlas',width=1024,height=1024,alpha=False)
    rgba=np.ones((1024,1024,4),np.float32)
    v,u=np.mgrid[0:256,0:256].astype(np.float32)/255
    for i,color in enumerate(PALETTES[hero]):
        rgb=np.array([int(color[j:j+2],16)/255 for j in (0,2,4)])
        shade=.93+.07*v+.025*np.sin(math.pi*u)
        if i in (2,3,10): shade+=.035*np.cos(u*math.tau*3+.4*np.sin(v*4))
        if i in (8,9): shade=.86+.13*np.sin(math.pi*u)+.035*v
        if i in (6,7): shade=.88+.13*np.sin(math.pi*u)+.02*v
        if i==0:
            shade=.98-.035*(2*u-1)**2
        if i in (11,12,13,15): shade=np.ones_like(u)
        row,col=divmod(i,4)
        rgba[row*256:(row+1)*256,col*256:(col+1)*256,:3]=np.clip(rgb[None,None,:]*shade[:,:,None],0,1)
    # PNG palette is authored sRGB, just as in Kael retro's corrected atlas.
    image.pixels.foreach_set(rgba.ravel())
    image.filepath_raw=str(out/(hero+'_atlas.png'));image.file_format='PNG';image.save();image.pack()
    image.filepath_raw='//'+hero+'_atlas.png'
    mats=[]
    for name,metal,rough in [('ClothSkin',0,.88),('Metal',.30,.65),('Crystal',.1,.50)]:
        mat=bpy.data.materials.new(hero.title()+name);mat.use_nodes=True
        node=mat.node_tree.nodes.get('Principled BSDF')
        node.inputs['Metallic'].default_value=metal;node.inputs['Roughness'].default_value=rough
        node.inputs['Specular IOR Level'].default_value=.22
        tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=image
        mat.node_tree.links.new(tex.outputs['Color'],node.inputs['Base Color'])
        if name=='Crystal':
            mat.node_tree.links.new(tex.outputs['Color'],node.inputs['Emission Color'])
            node.inputs['Emission Strength'].default_value=.22
        mats.append(mat)
    return mats

def rig_create(hero,c):
    data=bpy.data.armatures.new(hero.title()+'Skeleton');rig=bpy.data.objects.new(hero.title()+'Rig',data)
    bpy.context.collection.objects.link(rig);bpy.context.view_layer.objects.active=rig;rig.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    desc={'root':((0,0,0),(0,0,.14),None),
          'pelvis':((0,0,c['hip']),(0,0,c['waist']),'root'),
          'spine':((0,0,c['waist']),(0,0,c['shoulder']),'pelvis'),
          'neck':((0,0,c['shoulder']),(0,0,c['neck']),'spine'),
          'head':((0,0,c['neck']),(0,0,c['top']),'neck')}
    for sign,side in [(-1,'L'),(1,'R')]:
        def p(x,y,z):return(sign*x,y,z)
        desc.update({
          'upper_arm.'+side:(p(c['sx'],0,c['shoulder']-.015),p(c['elbow'],-.015,c['shoulder']-.28),'spine'),
          'forearm.'+side:(p(c['elbow'],-.015,c['shoulder']-.28),p(c['wrist'],-.06,c['shoulder']-.51),'upper_arm.'+side),
          'hand.'+side:(p(c['wrist'],-.06,c['shoulder']-.51),p(c['wrist']+.012,-.085,c['shoulder']-.625),'forearm.'+side),
          'thigh.'+side:(p(c['legx'],0,c['hip']+.02),p(c['legx']+.008,-.012,c['knee']),'pelvis'),
          'calf.'+side:(p(c['legx']+.008,-.012,c['knee']),p(c['legx']+.008,0,.17),'thigh.'+side),
          'foot.'+side:(p(c['legx']+.008,0,.17),p(c['legx']+.008,-.15,.05),'calf.'+side)})
    for name,(head,tail,parent) in desc.items():
        bone=data.edit_bones.new(name);bone.head=head;bone.tail=tail
        if parent:bone.parent=data.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT');return rig

def band(s,path,width,color,bone): s.strap(path,width,color,bone)

def pin(s,x,y,z,size,color,bone):
    # Leaf-like convex ornament, never a religious or franchise symbol.
    outline=[(x,y,z+size),(x+size*.55,y,z),(x,y,z-size),(x-size*.55,y,z)]
    for j in range(4):s.patch([(x,y-.012,z),outline[j],outline[(j+1)%4]],color,bone,True)

def buckle(s,x,y,z,w,h,bone):
    s.line([(x-w/2,y,z-h/2),(x+w/2,y,z-h/2),(x+w/2,y,z+h/2),(x-w/2,y,z+h/2),(x-w/2,y,z-h/2)],.003,'Gold',bone,5)

def torso(s,hero,c):
    h,w,sh=c['hip'],c['width'],c['shoulder']
    profiles=[(h-.06,w*.97,.105,'pelvis'),(h+.03,w,.115,'pelvis'),
              (c['waist'],w*.79,.083,'spine'),(sh-.28,w*.88,.10,'spine'),
              (sh-.16,w,.115,'spine'),(sh-.04,w*.96,.10,'spine'),(sh+.035,.065,.052,'neck')]
    s.rings([((0,0,z),rx,ry,b) for z,rx,ry,b in profiles],'Navy',28)
    s.rings([((0,0,sh+.01),.048,.043,'neck'),((0,0,c['chin']+.04),.045,.042,{'neck':.5,'head':.5})],'Skin',20)
    # A broad waist sash and a practical leather belt, not many tiny ornaments.
    for z,rx,ry,color,height in [(c['waist']-.04,w*.86,.096,'BlueCloth',.09),(h+.04,w*1.025,.121,'Leather',.04)]:
        s.rings([((0,0,z+dz),rx,ry,'pelvis') for dz in (-height/2,height/2)],color,28)
    buckle(s,.015,-.127,h+.04,.065,.049,'pelvis')
    if hero=='lyra':
        # Angular open indigo jacket with violet lapels and one draped shoulder.
        for sign in [-1,1]:
            poly=[(sign*.035,-.116,sh-.29),(sign*.115,-.115,sh-.15),(sign*.087,-.064,sh+.04),(sign*.035,-.065,sh+.045)]
            s.patch(poly,'BlueCloth','spine',True)
            s.line(poly[:3],.003,'Silver','spine',5)
        band(s,[(-.13,-.094,sh-.06),(0,-.125,sh-.23),(.13,-.094,sh-.06)],.014,'Silver','spine')
        pin(s,0,-.142,sh-.235,.035,'Crystal','spine')
        s.rings([((-.226,0,sh+.012),.08,.084,'upper_arm.L'),((-.25,.012,sh-.13),.093,.097,'upper_arm.L')],'BlueCloth',20)
    else:
        # Soft cream shoulder wrap, cut with a shallow V at the front and a
        # scalloped edge; volume derives from several cloth contours.
        rows=[];n=36
        for layer in range(5):
            t=layer/4;row=[]
            for i in range(n):
                a=i*math.tau/n;x=math.cos(a)*(.065+.235*t);y=math.sin(a)*(.055+.113*t)
                z=sh+.095-.17*t-.055*max(0,-math.sin(a))*(1-t)+.009*math.cos(a*6)*t
                weights={'spine':1.0}
                if abs(x)>.20:weights={'spine':.35,'upper_arm.'+('R' if x>0 else 'L'):.65}
                row.append(s.vertex((x,y,z),weights))
            rows.append(row)
        for a,b in zip(rows,rows[1:]):
            for i in range(n):s.face((a[i],a[(i+1)%n],b[(i+1)%n],b[i]),'BlueCloth')
        pin(s,-.035,-.139,sh-.04,.037,'Gold','spine')
        pin(s,.002,-.144,sh-.065,.026,'Navy','spine')
    # A shaped satchel differs in scale and side between the two designs.
    sign=1 if hero=='lyra' else -1
    px=sign*(w+.015);py=-.005;z=h-.05
    s.rings([((px,py,z+dz),rx,ry,'pelvis') for dz,rx,ry in [(-.12,.038,.029),(-.10,.049,.038),(.035,.046,.035),(.05,.035,.026)]],'DarkLeather',12)
    s.patch([(px-.048,-.044,z+.035),(px+.048,-.044,z+.035),(px+.038,-.047,z-.035),(px,-.052,z-.055),(px-.038,-.047,z-.035)],'Leather','pelvis',True)
    pin(s,px,-.056,z-.015,.014,'Silver' if hero=='lyra' else 'Gold','pelvis')

def coat(s,hero,c):
    h=c['hip'];n=12
    # Separate side/back fabric panels leave an open front for a walking stride.
    for sign in [-1,1]:
        rows=[]
        for j in range(6):
            t=j/5;radius=c['width']*(1.02+.22*t)
            hem=.64 if hero=='nira' else (.58 if sign<0 else .75)
            z=h+.035+(hem-h-.035)*t
            row=[]
            for i in range(n):
                a=-.95+i/(n-1)*2.45
                x=sign*radius*math.cos(a);y=radius*.72*math.sin(a)
                zz=z+.025*math.sin(i*math.pi/(n-1))*t
                weights={'pelvis':1-t*.55,'thigh.'+('R' if sign>0 else 'L'):t*.55}
                row.append(s.vertex((x,y,zz),weights))
            rows.append(row)
        for j,(a,b) in enumerate(zip(rows,rows[1:])):
            for i in range(n-1):s.face((a[i],a[i+1],b[i+1],b[i]),'Navy' if hero=='nira' else 'BlueCloth',[(i/(n-1),j/5),((i+1)/(n-1),j/5),((i+1)/(n-1),(j+1)/5),(i/(n-1),(j+1)/5)])
        edge=[s.v[row[0]] for row in rows]
        s.line(edge,.003,'Gold' if hero=='nira' else 'Silver','pelvis',5)
    if hero=='nira':
        # A short cream apron panel, shaped and separated from the trousers.
        rows=[]
        for j in range(5):
            t=j/4;row=[]
            for i in range(9):
                u=(i/8-.5)*2;x=u*(.12+.035*t)
                row.append(s.vertex((x,-.125-.022*t+.025*u*u,h-.015-.29*t+.025*u*u*t),'pelvis'))
            rows.append(row)
        for a,b in zip(rows,rows[1:]):
            for i in range(8):s.face((a[i],a[i+1],b[i+1],b[i]),'BlueCloth')
        for sign in [-1,1]:pin(s,sign*.045,-.151,h-.17,.022,'Navy','pelvis')

def limbs(s,hero,c):
    h,sh,knee=c['hip'],c['shoulder'],c['knee']
    for sign,side in [(-1,'L'),(1,'R')]:
        thigh,calf,foot=['%s.%s'%(b,side) for b in ('thigh','calf','foot')]
        ua,fa,hand=['%s.%s'%(b,side) for b in ('upper_arm','forearm','hand')]
        x=c['legx'];r=.078 if hero=='lyra' else .092
        s.rings([((sign*(x+dx),y,z),rx,ry,b) for dx,y,z,rx,ry,b in [
            (0,0,h+.02,r,r*.95,thigh),(.003,0,h-.12,r*.98,r*.94,thigh),
            (.006,-.006,knee+.11,r*.77,r*.78,thigh),(.008,-.012,knee,r*.64,r*.69,{thigh:.5,calf:.5}),
            (.008,0,knee-.12,r*.64,r*.66,calf),(.008,.003,.23,r*.48,r*.48,calf)]],'Trouser',20)
        # Curved toe, instep and fitted calf, with a single readable folded cuff.
        bx=sign*(x+.008)
        s.rings([((bx,y,z),rx,ry,b) for y,z,rx,ry,b in [
            (-.06,.025,.064,.126,foot),(-.062,.065,.065,.128,foot),(-.055,.11,.061,.119,foot),
            (-.024,.15,.048,.073,{foot:.7,calf:.3}),(0,.20,.046,.047,calf),(.004,.35,.058,.058,calf),
            (.002,.48,.061,.058,calf)]],'DarkLeather',20)
        s.rings([((bx,-.060,z),.066,.129,foot) for z in (.012,.028)],'Trouser',20)
        s.rings([((bx,0,z),rx,rx*.95,calf) for z,rx in [(.45,.062),(.48,.068),(.50,.067)]],'BlueCloth' if hero=='nira' else 'Leather',20)
        band(s,[(bx-.04,-.060,.32),(bx,-.063,.31),(bx+.04,-.06,.32)],.029,'Leather',calf)
        buckle(s,bx,-.067,.32,.027,.024,calf)
        sx,ex,wx=c['sx'],c['elbow'],c['wrist']
        arm_r=.057 if hero=='lyra' else .067
        s.rings([((sign*x,y,z),rx,ry,b) for x,y,z,rx,ry,b in [
            (sx,0,sh-.015,arm_r,arm_r,ua),(sx+.025,0,sh-.08,arm_r*1.02,arm_r,ua),
            (ex-.025,-.008,sh-.22,arm_r*.82,arm_r*.88,ua),
            (ex,-.015,sh-.28,arm_r*.78,arm_r*.8,{ua:.4,fa:.6}),
            (ex+.025,-.032,sh-.36,arm_r*.78,arm_r*.78,fa),
            (wx,-.06,sh-.51,.032,.032,fa)]],'Navy' if hero=='lyra' else 'BlueCloth',20)
        # Lyra has violet flared cuffs; Nira has fitted travel bracers.
        s.rings([((sign*x,y,z),rx,ry,fa) for x,y,z,rx,ry in [
            (ex+.015,-.026,sh-.33,.05,.052),(wx-.013,-.05,sh-.46,.045,.045),
            (wx,-.06,sh-.515,.052 if hero=='lyra' else .038,.052 if hero=='lyra' else .037)]],'BlueCloth' if hero=='lyra' else 'Leather',18)
        wz=sh-.51
        s.rings([((sign*(wx+dx),y,z),rx,ry,hand) for dx,y,z,rx,ry in [(0,-.06,wz,.031,.027),(.007,-.069,wz-.045,.035,.026),(.012,-.074,wz-.08,.034,.022)]],'Skin',16)
        # Individually curved fingers; right hand closes around the cosmetic focus.
        for i in range(4):
            if side=='R':
                z=wz-.075+i*.015
                pts=[(wx-.018,-.075,z),(wx-.010,-.108,z),(wx+.012,-.119,z),(wx+.032,-.103,z),(wx+.026,-.088,z)]
                s.line(surface_tools.catmull(pts,2),.0075,'Skin',hand,6)
            else:
                xx=sign*(wx-.020+i*.016);length=[.039,.049,.046,.035][i]
                s.rings([((xx,y,z),rx,ry,hand) for y,z,rx,ry in [(-.075,wz-.07,.008,.012),(-.082,wz-.09,.009,.011),(-.088,wz-.09-length*.6,.008,.009),(-.082,wz-.09-length,.006,.007)]],'Skin',8)
        s.line(surface_tools.catmull([(sign*(wx-.028),-.071,wz-.025),(sign*(wx-.038),-.095,wz-.055),(sign*(wx-.021),-.113,wz-.068)],3),.010,'Skin',hand,7)

def head(s,hero,c):
    chin,top=c['chin'],c['top'];height=top-chin
    half=.117 if hero=='lyra' else .128
    profile=[(0,.28,.56),(.06,.47,.70),(.15,.68,.79),(.25,.84,.87),(.36,.96,.96),(.47,1,1),(.59,.97,.99),(.70,.95,.96),(.81,.91,.91),(.90,.77,.78),(.97,.48,.49),(1,.10,.10)]
    def depth(x,z):
        t=(z-chin)/height
        segment=next(((a,b) for a,b in zip(profile,profile[1:]) if a[0]<=t<=b[0]),(profile[-2],profile[-1]))
        a,b=segment;f=max(0,min(1,(t-a[0])/(b[0]-a[0])))
        width=half*(a[1]*(1-f)+b[1]*f);front=.104*(a[2]*(1-f)+b[2]*f)
        y=-front*(.83+.17*math.sqrt(max(0,1-(x/max(width,.001))**2)))
        y-=.009*math.exp(-(x/.022)**2-((t-.40)/.10)**2)
        return y
    rows=[];n=48
    for t,width,d in profile:
        z=chin+t*height;row=[]
        for i in range(n):
            a=i*math.tau/n;x=half*width*math.cos(a);y=.105*d*math.sin(a)
            if math.sin(a)<-.25:
                f=min(1,(-math.sin(a)-.25)/.25);y=y*(1-f)+depth(x,z)*f
            row.append(s.vertex((x,y,z),'head'))
        rows.append(row)
    for j,(a,b) in enumerate(zip(rows,rows[1:])):
        for i in range(n):
            k=(i+1)%n
            ids=(a[i],a[k],b[k],b[i]);uv=[(.5+s.v[index][0]/(half*2.1),(s.v[index][2]-chin)/height) for index in ids]
            s.face(ids,'Face',uv)
    s.face(tuple(reversed(rows[0])),'Skin');s.face(rows[-1],'Face')
    eye_z=chin+height*.59
    for sign in [-1,1]:
        # Small shaped ears with a soft inner plane.
        ear=[(sign*half*.91,-.008,eye_z+.01),(sign*half*1.13,-.002,eye_z+.02),(sign*half*1.16,.003,eye_z-.015),(sign*half*1.03,-.009,eye_z-.05),(sign*half*.92,-.012,eye_z-.03)]
        for j in range(5):s.patch([(sign*half*1.01,-.014,eye_z-.012),ear[j],ear[(j+1)%5]],'Skin','head',True)
        cx=sign*.048
        boundary=[(-.031,-.001),(-.018,.013),(0,.016),(.019,.011),(.033,-.002),(.018,-.011),(0,-.012),(-.018,-.009)]
        points=[(cx+sign*x,depth(cx+sign*x,eye_z+z)-.002,eye_z+z) for x,z in boundary]
        center=(cx,depth(cx,eye_z)-.003,eye_z)
        ids=[s.vertex(p,'head') for p in points];mid=s.vertex(center,'head')
        for j in range(8):s.face((mid,ids[j],ids[(j+1)%8]),'White')
        for rx,rz,color,layer in [(.013,.015,'Iris',.004),(.006,.009,'Ink',.005)]:
            ring=[]
            for j in range(20):
                a=j*math.tau/20;x=cx+rx*math.cos(a);z=eye_z+rz*math.sin(a)
                ring.append(s.vertex((x,depth(x,z)-layer,z),'head'))
            mid=s.vertex((cx,depth(cx,eye_z)-layer,eye_z),'head')
            for j in range(20):s.face((mid,ring[j],ring[(j+1)%20]),color)
        s.patch([(cx-.005,depth(cx,eye_z)-.006,eye_z+.008),(cx-.001,depth(cx,eye_z)-.006,eye_z+.008),(cx-.003,depth(cx,eye_z)-.006,eye_z+.004)],'White','head')
        s.line([(x,y-.0015,z) for x,y,z in points[:5]],.0011,'Ink','head',5)
        brow=[]
        for x,dz in [(sign*.019,0),(sign*.043,.006),(sign*.070,.007),(sign*.085,.001)]:
            z=eye_z+.034+dz+(0 if hero=='nira' else .05*(abs(x)-.04))
            brow.append((x,depth(x,z)-.003,z))
        s.strap(brow,.007 if hero=='lyra' else .006,'Hair','head')
    mz=chin+height*.245
    pts=[(-.027,depth(-.027,mz)-.002,mz+.002),(0,depth(0,mz)-.002,mz),(.027,depth(.027,mz)-.002,mz+(.004 if hero=='nira' else .002))]
    s.line(surface_tools.catmull(pts,3),.0011,'Lip','head',5)

def hair(s,hero,c):
    top,chin=c['top'],c['chin'];half=.12 if hero=='lyra' else .132
    s.rings([((0,.016,z),rx,ry,'head') for z,rx,ry in [(top-.14,half,.10),(top-.065,half*1.04,.112),(top+.005,half*.74,.085),(top+.045,.025,.03)]],'Hair',36)
    # Rear scalp cover and a few broad swept locks. Different silhouettes.
    rows=[]
    for z,r in [(chin+.10,half*.85),(chin+.18,half*1.03),(top-.05,half)]:
        rows.append([s.vertex((r*math.cos(i*math.pi/24),.012+.11*math.sin(i*math.pi/24),z),'head') for i in range(25)])
    for a,b in zip(rows,rows[1:]):
        for i in range(24):s.face((a[i],a[i+1],b[i+1],b[i]),'Hair')
    if hero=='lyra':
        bangs=[([(.08,.025,top+.015),(.04,-.060,top+.02),(-.025,-.12,top-.045),(-.115,-.115,top-.11)],[.025,.046,.035,.001]),
               ([(.10,.03,top-.01),(.13,-.07,top-.035),(.145,-.085,top-.12),(.15,-.06,top-.27)],[.024,.032,.026,.001]),
               ([(-.015,.03,top+.04),(-.075,-.035,top+.01),(-.12,-.065,top-.14),(-.13,-.04,chin+.10)],[.023,.041,.033,.001])]
        for i,(path,widths) in enumerate(bangs):surface_tools.hair_lock(s,path,widths,'HairLight' if i==0 else 'Hair')
        for sign in [-1,1]:
            for j in range(4):
                y=.01+j*.028
                surface_tools.hair_lock(s,[(sign*.08,y,top), (sign*.133,y+.02,top-.12),(sign*.13,y+.025,chin+.08),(sign*.11,y+.01,chin-.09)],[.026,.037,.032,.001],'HairLight' if j==1 else 'Hair',side=(.8,1,0))
        # A tied side tail gives the mage a recognizable asymmetry at distance.
        for j in range(5):
            x=.11+(j-2)*.017
            surface_tools.hair_lock(s,[(x,.09,top-.055),(x+.10,.15,top-.06),(x+.12,.19,chin+.08),(x+.07,.18,chin-.15)],[.020,.033,.028,.001],'HairLight' if j in (1,3) else 'Hair')
        s.line([(.10,.095,top-.08),(.17,.12,top-.09),(.20,.145,top-.12)],.010,'Silver','head',8)
    else:
        # Warm wavy bob with swept fringe, rounded side locks and a low knot.
        for sign in [-1,1]:
            for j in range(4):
                y=-.04+j*.038
                surface_tools.hair_lock(s,[(sign*.05,y,top+.02),(sign*.13,y-.012,top-.07),(sign*.16,y+.02,chin+.17),(sign*.12,y+.04,chin+.075)],[.025,.040,.037,.002],'HairLight' if j in (0,2) else 'Hair',side=(1,.35,0))
        for j in range(4):
            x=-.07+j*.045
            surface_tools.hair_lock(s,[(x+.035,.02,top+.025),(x+.015,-.08,top+.01),(x-.025,-.116,top-.07),(x-.035,-.112,top-.14)],[.022,.038,.028,.001],'HairLight' if j%2 else 'Hair')
        for j in range(6):
            a=j*math.tau/6
            path=[(.04*math.cos(a),.10,chin+.23),(.072*math.cos(a),.17,chin+.22+.06*math.sin(a)),(.045*math.cos(a),.20,chin+.16),(.01,.17,chin+.13)]
            surface_tools.hair_lock(s,path,[.025,.032,.025,.001],'HairLight' if j%2 else 'Hair')
        pin(s,-.132,-.05,top-.10,.029,'Navy','head')

def focus(hero,c):
    s=Surface();x=c['wrist']+.008;y=-.103;z=c['shoulder']-.565;b='hand.R'
    s.rings([((x,y,zz),r,r,b) for zz,r in [(z-.18,.014),(z-.05,.014),(z+.28,.012),(z+.38,.017)]],'DarkLeather',14)
    for zz in [z-.07,z+.10,z+.28]:s.rings([((x,y,k),.017,.017,b) for k in (zz,zz+.016)],'Silver' if hero=='lyra' else 'Gold',12)
    if hero=='lyra':
        for sign in [-1,1]:
            s.line(surface_tools.catmull([(x,y,z+.27),(x+sign*.07,y,z+.35),(x+sign*.075,y,z+.46),(x+sign*.045,y,z+.52)],3),.009,'Silver',b,7)
        pin(s,x,y,z+.44,.09,'Crystal',b)
    else:
        for sign in [-1,1]:
            s.line(surface_tools.catmull([(x,y,z+.23),(x+sign*.055,y,z+.32),(x+sign*.07,y,z+.43),(x+sign*.028,y,z+.48)],3),.012,'Leather',b,7)
            pin(s,x+sign*.065,y-.007,z+.37,.05,'Navy',b)
        pin(s,x,y-.015,z+.43,.055,'Crystal',b)
    return s

def style_face_proportions(surface,c):
    # Shared art direction, applied to each independently authored face/hair.
    # Shorter lower face and neck, broader head; no change to hands or joints.
    eye=c['chin']+(c['top']-c['chin'])*.59
    for i,(point,weights) in enumerate(zip(surface.v,surface.w)):
        amount=weights.get('head',0)
        if amount<=0:continue
        x,y,z=point
        styled=Vector((x*1.10,y,eye+(z-eye)*(.82 if z<eye else 1.08)-.055))
        surface.v[i]=tuple(Vector(point).lerp(styled,amount))

def rotate(rig,poses):
    for name,angles in poses.items():rig.pose.bones[name].rotation_quaternion=Euler(angles,'XYZ').to_quaternion()

def offset(rig,name,delta):
    rig.pose.bones[name].location=rig.data.bones[name].matrix_local.to_3x3().inverted()@Vector(delta)

def aim(rig,name,start,end):
    bone=rig.data.bones[name];q=(bone.tail_local-bone.head_local).normalized().rotation_difference((end-start).normalized())
    matrix=(q.to_matrix()@bone.matrix_local.to_3x3()).to_4x4();matrix.translation=start
    rig.pose.bones[name].matrix=matrix;bpy.context.view_layer.update()

def chain(rig,upper,lower,tip,target,bend):
    start=rig.pose.bones[upper].head.copy();a=rig.data.bones[upper].length;b=rig.data.bones[lower].length
    delta=target-start;distance=min(delta.length,a+b-.001);axis=delta.normalized();target=start+axis*distance
    along=(a*a-b*b+distance*distance)/(2*distance);pole=(bend-axis*axis.dot(bend)).normalized()
    middle=start+axis*along+pole*math.sqrt(max(0,a*a-along*along))
    aim(rig,upper,start,middle);aim(rig,lower,middle,target)
    matrix=rig.data.bones[tip].matrix_local.copy();matrix.translation=target;rig.pose.bones[tip].matrix=matrix
    bpy.context.view_layer.update()

def pose(rig,hero,c,clip,t):
    for b in rig.pose.bones:b.rotation_mode='QUATERNION';b.matrix_basis=Matrix.Identity(4)
    breath=math.sin(t*math.tau) if clip=='Idle' else 0
    rotate(rig,{'spine':(.015,0,-.02 if hero=='lyra' else .01),'head':(0,.025 if hero=='lyra' else -.02,0),
        'upper_arm.L':(-.10,0,.05),'forearm.L':(-.14,0,0),'upper_arm.R':(-.12,0,-.05),'forearm.R':(-.20,0,0)})
    rig.pose.bones['spine'].scale=Vector((1+breath*.004,1,1+breath*.006))
    bpy.context.view_layer.update()
    sh=c['shoulder'];wx=c['wrist']
    if clip=='Walk':
        phase=t*math.tau;offset(rig,'pelvis',(0,0,-.09+.008*math.cos(phase*2)))
        rotate(rig,{'upper_arm.L':(.26*math.cos(phase),0,.05),'upper_arm.R':(-.12-.12*math.cos(phase),0,-.05),'spine':(.025,.018*math.sin(phase),0)})
        bpy.context.view_layer.update()
        for side,shift in [('L',0),('R',.5)]:
            q=(t+shift)%1;travel=-.35+.70*q*2 if q<.5 else .35-.70*smooth((q-.5)*2)
            lift=0 if q<.5 else .12*math.sin(math.pi*(q-.5)*2)
            target=rig.data.bones['foot.'+side].head_local.copy()+Vector((0,travel,lift))
            chain(rig,'thigh.'+side,'calf.'+side,'foot.'+side,target,Vector((0,-1,0)))
    elif clip in ('Cast','Support','Attack','Defend'):
        amount=smooth(min(1,t/.33))*(1-smooth(max(0,(t-.70)/.30))) if clip!='Defend' else smooth(min(1,t/.7))
        targets={
          'Cast':{'L':Vector((-.27,-.39,sh-.02)),'R':Vector((wx+.04,-.22,sh-.18))},
          'Support':{'L':Vector((-.24,-.34,sh-.15)),'R':Vector((wx,-.20,sh-.22))},
          'Defend':{'L':Vector((-.15,-.29,sh-.15)),'R':Vector((wx,-.24,sh-.26))},
          'Attack':{'L':Vector((-.22,-.25,sh-.25)),'R':Vector((wx+.045,-.44,sh-.26))},
        }[clip]
        for side in ('L','R'):
            start=rig.pose.bones['hand.'+side].head.copy()
            target=start.lerp(targets[side],amount)
            chain(rig,'upper_arm.'+side,'forearm.'+side,'hand.'+side,target,Vector((1 if side=='R' else -1,0,-.2)))
            # Palm opens toward the spell; focus stays upright and outside torso.
            if side=='L' and clip in ('Cast','Support'):
                matrix=rig.pose.bones['hand.L'].matrix.copy()
                matrix=matrix@Matrix.Rotation(-.7*amount,4,'X');rig.pose.bones['hand.L'].matrix=matrix
    elif clip=='Hurt':
        amount=math.sin(math.pi*t)**2
        rotate(rig,{'spine':(-.17*amount,.04*amount,0),'head':(.10*amount,0,0),'forearm.L':(-.14-.2*amount,0,0)})
    elif clip=='KO':
        u=smooth(t)
        rotate(rig,{'root':(-1.50*u,0,.08*u),'head':(.12*u,0,0),'thigh.L':(-.19*u,0,0),'calf.L':(.40*u,0,0),'foot.L':(-.18*u,0,0),
                    'upper_arm.L':(.05,0,.34*u),'upper_arm.R':(.05,0,-.36*u),'forearm.R':(-.16,0,0)})
    bpy.context.view_layer.update()

def min_z(objects):
    deps=bpy.context.evaluated_depsgraph_get();low=100
    for obj in objects:
        ev=obj.evaluated_get(deps);mesh=ev.to_mesh();low=min(low,min((ev.matrix_world@v.co).z for v in mesh.vertices));ev.to_mesh_clear()
    return low

def animate(rig,objects,hero,c):
    lengths={'Idle':3.0,'Walk':.7,'Attack':.65,'Hurt':.4,'Defend':.45,'KO':1.0,('Cast' if hero=='lyra' else 'Support'):(.85 if hero=='lyra' else 1.0)}
    rig.animation_data_clear()
    for action in list(bpy.data.actions):bpy.data.actions.remove(action)
    checks={}
    for clip,seconds in lengths.items():
        action=bpy.data.actions.new(clip);action.use_fake_user=True;rig.animation_data_create();rig.animation_data.action=action
        count=round(seconds*FPS);minima=[]
        for frame in range(count+1):
            bpy.context.scene.frame_set(frame+1);pose(rig,hero,c,clip,frame/count)
            z=min_z(objects)
            if z<.008 or clip=='KO':
                matrix=rig.pose.bones['root'].matrix.copy();matrix.translation.z+=.008-z;rig.pose.bones['root'].matrix=matrix;bpy.context.view_layer.update()
            minima.append(min_z(objects))
            for bone in rig.pose.bones:
                for channel in ('location','rotation_quaternion','scale'):bone.keyframe_insert(channel,frame=frame+1,group=bone.name)
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        for key in curve.keyframe_points:key.interpolation='LINEAR'
        checks[clip]={'seconds':seconds,'min_vertex_z':min(minima)}
    rig.animation_data.action=bpy.data.actions['Idle'];bpy.context.scene.frame_set(1)
    return checks,lengths

def export(hero,rig,objects,out,checks,lengths):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in [rig]+objects:obj.select_set(True)
    bpy.context.view_layer.objects.active=rig
    bpy.ops.export_scene.gltf(filepath=str(out/(hero+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_skins=True,
        export_def_bones=False,export_animations=True,export_animation_mode='ACTIONS',export_merge_animation='ACTION',export_anim_single_armature=True,export_anim_slide_to_zero=True,export_extras=True,export_force_sampling=True)
    blob=(out/(hero+'.glb')).read_bytes();length=struct.unpack_from('<I',blob,12)[0];gltf=json.loads(blob[20:20+length])
    primitives=[p for m in gltf['meshes'] for p in m['primitives']]
    assert all('uri' not in p for p in gltf['buffers']+gltf['images'])
    report={'character':hero,'art_revision':'retro-companions','blender':bpy.app.version_string,
      'method':'Original contour garment and anatomical meshes; no Kael character geometry copied',
      'triangles':sum(gltf['accessors'][p['indices']]['count']//3 for p in primitives),
      'exported_vertices':sum(gltf['accessors'][p['attributes']['POSITION']]['count'] for p in primitives),
      'author_vertices':sum(len(obj.data.vertices) for obj in objects),'surfaces':len(primitives),'materials':len(gltf['materials']),
      'bones':len(rig.data.bones),'animations':[a['name'] for a in gltf['animations']],'animation_checks':checks,
      'glb_bytes':len(blob),'texture_size':[1024,1024],'walk_reference_speed':2.0,'locomotion_blend':.12,'lunge_distance':0.0,
      'presentation_durations':lengths,'authored_sections':sum(len(obj.data.polygons) for obj in objects),
      'glb_sha256':sha(out/(hero+'.glb')),'blend_sha256':sha(out/(hero+'.blend')),'atlas_sha256':sha(out/(hero+'_atlas.png')),
      'build_script_sha256':sha(Path(__file__)),'surface_helper_sha256':sha(Path(surface_tools.__file__)),
      'kael_reference_glb_sha256':sha(ROOT/'assets/characters/kael/retro/kael.glb'),'mobile_tested':False}
    (out/(hero+'_manifest.json')).write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8');print('COMPANION',json.dumps(report))

if not bpy.app.background:raise RuntimeError('Use a separate background Blender process')
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
heroes=[args[args.index('--hero')+1]] if '--hero' in args else ['lyra','nira']
for hero in heroes:
    assert hero in CONFIG
    out=ROOT/'assets/characters'/hero;out.mkdir(parents=True,exist_ok=True)
    if '--export-only' in args:
        bpy.ops.wm.open_mainfile(filepath=str(out/(hero+'.blend')))
        report=json.loads((out/(hero+'_manifest.json')).read_text(encoding='utf-8'));checks=report['animation_checks'];lengths=report['presentation_durations']
        rig=bpy.data.objects[hero.title()+'Rig'];objects=[bpy.data.objects[hero.title()+'Body'],bpy.data.objects['Focus']]
    else:
        bpy.ops.wm.read_factory_settings(use_empty=True);c=CONFIG[hero];rig=rig_create(hero,c);mats=materials(hero,out)
        body=Surface();torso(body,hero,c);coat(body,hero,c);limbs(body,hero,c);head(body,hero,c);hair(body,hero,c);style_face_proportions(body,c)
        body_obj=body.object(hero.title()+'Body',rig,mats);focus_obj=focus(hero,c).object('Focus',rig,mats);objects=[body_obj,focus_obj]
        bpy.context.scene.render.fps=FPS;checks,lengths=animate(rig,objects,hero,c)
        staging=out/(hero+'.generated.blend');bpy.ops.wm.save_as_mainfile(filepath=str(staging),check_existing=False);staging.replace(out/(hero+'.blend'))
    export(hero,rig,objects,out,checks,lengths)
