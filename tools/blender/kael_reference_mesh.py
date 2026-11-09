"""Locally authored mesh study from the user's Kael turnaround.

Explicit surfaces, garment sections and facial landmarks; no downloaded geometry,
image generation service, or third-party texture. The atlas is algorithmic artwork,
not a claim of hand-painted production art. Blender Z-up, face -Y.
"""
import math
import bpy
import numpy as np
from mathutils import Vector

PALETTE = {
    'Face': 'd9bba3', 'Skin': 'cfad90', 'Navy': '354b72', 'BlueCloth': '526c95',
    'Leather': '795541', 'DarkLeather': '423932', 'Silver': 'abb9c7', 'Gold': 'c9a571',
    'Hair': '483029', 'HairLight': '634432', 'Trouser': '343740', 'White': 'ddd6ca',
    'Iris': '946241', 'Ink': '241d20', 'Crystal': '328bcb', 'Lip': 'a37061',
}


def materials(out):
    size = 1024
    tile = size // 4
    image = bpy.data.images.new('KaelReferenceAtlas', width=size, height=size, alpha=False)
    rgba = np.ones((size, size, 4), dtype=np.float32)
    v, u = np.mgrid[0:tile, 0:tile].astype(np.float32) / (tile - 1)
    for i, (name, color) in enumerate(PALETTE.items()):
        rgb = np.array([int(color[j:j+2],16)/255 for j in (0,2,4)])
        shade = .83 + .18*v + .06*np.sin(u*math.pi)
        grain = .006 * np.sin(u*2311+v*1973) * np.cos(u*941-v*753)
        tint = np.zeros((tile,tile,3),dtype=np.float32)
        if name == 'Face':
            shade = .98 - .10*(2*u-1)**2 + .025*v
            # Subtle cheeks, sockets and mouth/nose shading in face-space UV.
            cheeks = np.exp(-((np.abs(u-.5)-.29)/.13)**2-((v-.38)/.12)**2)
            tint += cheeks[:,:,None] * np.array([.025,-.026,-.029])
            sockets = np.exp(-((np.abs(u-.5)-.22)/.13)**2-((v-.58)/.05)**2)
            shade -= sockets*.07
            shade -= .08*np.exp(-((u-.5)/.10)**2-((v-.31)/.035)**2)
        elif name in ('Hair','HairLight'):
            shade = .65 + .35*np.sin(math.pi*u)**.7 + .12*np.sin(math.pi*v)
            shade += .045*np.sin(u*95 + np.sin(v*8)*2) + .018*np.sin(u*239+v*5)
        elif name in ('Navy','BlueCloth','Trouser'):
            phase = u*math.tau*4 + .5*np.sin(v*7)
            shade += .07*np.cos(phase) - .06*np.exp(-(np.sin(phase)/.30)**2)
            shade += .006*np.sin(u*tile*math.pi)*np.cos(v*tile*math.pi)
            shade -= .12*np.exp(-((u-.02)/.015)**2)
        elif name in ('Leather','DarkLeather'):
            shade += .024*np.sin(u*130+np.sin(v*80))
            shade += .13*np.exp(-((np.minimum(u,1-u)-.045)/.013)**2)
        elif name in ('Silver','Gold'):
            shade = .72 + .27*np.sin(math.pi*u) + .12*v
            shade += .012*np.sin(v*400+u*30)
        elif name == 'Crystal':
            shade = .6 + .65*np.exp(-((u-.5)/.20)**2)
        elif name in ('White','Iris','Ink','Lip'):
            shade = .95 + .05*v
        pixels = np.clip(rgb[None,None,:]*(shade+grain)[:,:,None]+tint,0,1)
        row,col = divmod(i,4)
        rgba[row*tile:(row+1)*tile,col*tile:(col+1)*tile,:3] = pixels
    # Blender image pixels are scene-linear; the palette above is authored sRGB.
    # Without this conversion the saved atlas is washed out by a second gamma.
    rgb = rgba[:,:,:3]
    rgba[:,:,:3] = np.where(rgb <= .04045, rgb / 12.92, ((rgb + .055) / 1.055) ** 2.4)
    image.pixels.foreach_set(rgba.ravel())
    image.filepath_raw = str(out/'kael_atlas.png')
    image.file_format = 'PNG'
    image.save()
    image.pack()
    image.filepath_raw = '//kael_atlas.png'
    mats=[]
    for name,metal,rough in [('KaelClothSkin',0,.83),('KaelMetal',.65,.39),('KaelCrystal',.25,.25)]:
        m=bpy.data.materials.new(name)
        m.use_backface_culling = False
        shader=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
        shader.inputs['Metallic'].default_value=metal
        shader.inputs['Roughness'].default_value=rough
        t=m.node_tree.nodes.new('ShaderNodeTexImage'); t.image=image
        m.node_tree.links.new(t.outputs['Color'],shader.inputs['Base Color'])
        if name=='KaelCrystal':
            m.node_tree.links.new(t.outputs['Color'],shader.inputs['Emission Color'])
            shader.inputs['Emission Strength'].default_value=.35
        mats.append(m)
    return mats


def weights(value):
    return {value:1.0} if isinstance(value,str) else value


class Surface:
    def __init__(self):
        self.v=[]; self.f=[]; self.w=[]; self.uv=[]; self.colors=[]; self.smooth=[]

    def vertex(self,point,bone):
        self.v.append(tuple(point)); self.w.append(weights(bone)); return len(self.v)-1

    def face(self,ids,color,uv=None,smooth=True):
        self.f.append(ids); self.colors.append(color); self.smooth.append(smooth)
        self.uv.append(uv or [(0.5+.45*math.cos(i*math.tau/len(ids)),.5+.45*math.sin(i*math.tau/len(ids))) for i in range(len(ids))])

    def patch(self,points,color,bone,smooth=False):
        self.face([self.vertex(p,bone) for p in points],color,smooth=smooth)

    def rings(self,profiles,color,n=16):
        """Each ring: (center, x radius, y radius, skin weights). Z-aligned garment."""
        rows=[]
        for center,rx,ry,bone in profiles:
            rows.append([self.vertex((center[0]+rx*math.cos(i*math.tau/n),center[1]+ry*math.sin(i*math.tau/n),center[2]),bone) for i in range(n)])
        for j,(a,b) in enumerate(zip(rows,rows[1:])):
            for i in range(n):
                k=(i+1)%n
                self.face((a[i],a[k],b[k],b[i]),color,[(i/n,j/(len(rows)-1)),((i+1)/n,j/(len(rows)-1)),((i+1)/n,(j+1)/(len(rows)-1)),(i/n,(j+1)/(len(rows)-1))])
        self.face(tuple(reversed(rows[0])),color)
        self.face(rows[-1],color)

    def line(self,points,radius,color,bone,n=6):
        """Thin trim or seam swept along a contour, not character anatomy."""
        rows=[]
        for j,p in enumerate(points):
            tangent=Vector(points[min(j+1,len(points)-1)])-Vector(points[max(0,j-1)])
            tangent.normalize()
            side=tangent.cross(Vector((0,-1,0)))
            if side.length < .01: side=tangent.cross(Vector((1,0,0)))
            side.normalize(); other=tangent.cross(side).normalized()
            rows.append([self.vertex(Vector(p)+radius*(side*math.cos(i*math.tau/n)+other*math.sin(i*math.tau/n)),bone) for i in range(n)])
        for a,b in zip(rows,rows[1:]):
            for i in range(n):
                k=(i+1)%n; self.face((a[i],a[k],b[k],b[i]),color)
        self.face(tuple(reversed(rows[0])),color); self.face(rows[-1],color)

    def strap(self,path,width,color,bone):
        rows=[]
        for j,p in enumerate(path):
            tangent=Vector(path[min(j+1,len(path)-1)])-Vector(path[max(0,j-1)])
            side=tangent.cross(Vector((0,-1,0))).normalized()*width/2
            rows.append([self.vertex(Vector(p)-side,bone),self.vertex(Vector(p)+side,bone)])
        for j,(a,b) in enumerate(zip(rows,rows[1:])):
            self.face((a[0],a[1],b[1],b[0]),color,[(0,j/(len(rows)-1)),(1,j/(len(rows)-1)),(1,(j+1)/(len(rows)-1)),(0,(j+1)/(len(rows)-1))])

    def object(self,name,rig,mats):
        mesh=bpy.data.meshes.new(name+'Mesh'); mesh.from_pydata(self.v,[],self.f); mesh.update()
        obj=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(obj)
        for mat in mats: mesh.materials.append(mat)
        uv=mesh.uv_layers.new(name='KaelReferenceUV')
        for poly,color,coords,smooth in zip(mesh.polygons,self.colors,self.uv,self.smooth):
            tile=list(PALETTE).index(color); row,col=divmod(tile,4)
            poly.material_index=1 if color in ('Silver','Gold') else (2 if color=='Crystal' else 0)
            poly.use_smooth=smooth
            for loop,(u,v) in zip(poly.loop_indices,coords):
                uv.data[loop].uv=((col+.015+.97*u)/4,(row+.015+.97*v)/4)
        for b in rig.data.bones: obj.vertex_groups.new(name=b.name)
        for i,w in enumerate(self.w):
            total=sum(w.values())
            for b,value in w.items(): obj.vertex_groups[b].add([i],value/total,'REPLACE')
        obj.parent=rig
        modifier=obj.modifiers.new('KaelSkin','ARMATURE'); modifier.object=rig
        bpy.context.view_layer.objects.active=obj; obj.select_set(True)
        bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode='OBJECT')
        obj.select_set(False)
        obj['authored_sections']=len(self.f)
        return obj


def catmull(points,steps=3):
    p=[Vector(points[0])]+[Vector(x) for x in points]+[Vector(points[-1])]
    out=[]
    for i in range(1,len(p)-2):
        a,b,c,d=p[i-1:i+3]
        for j in range(steps):
            t=j/steps
            out.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
    return out+[Vector(points[-1])]


def face_depth(x,z,width,front):
    y=-front*(.80+.20*math.sqrt(max(0,1-(x/max(.001,width))**2)))
    # Continuous cheek/muzzle/nasal bridge surfaces, not attached nose primitives.
    y-=.010*math.exp(-(x/.013)**2-((z-1.714)/.045)**2)
    y-=.015*math.exp(-(x/.016)**2-((z-1.688)/.016)**2)
    y-=.005*math.exp(-(x/.031)**2-((z-1.654)/.020)**2)
    y+=.006*math.exp(-((abs(x)-.038)/.021)**2-((z-1.736)/.013)**2)
    return y


def head(s):
    profiles=[(1.59,.023,.054,.040),(1.605,.041,.062,.050),(1.62,.057,.067,.057),
              (1.64,.068,.070,.066),(1.66,.077,.072,.074),(1.68,.081,.075,.080),
              (1.70,.083,.075,.084),(1.72,.082,.074,.086),(1.735,.080,.073,.086),
              (1.75,.079,.072,.085),(1.77,.078,.071,.083),(1.79,.074,.068,.078),
              (1.81,.061,.058,.065),(1.83,.037,.035,.040),(1.84,.008,.008,.008)]
    rows=[]; coords=[]; n=48
    for z,w,front,back in profiles:
        row=[]; tex=[]
        for i in range(n):
            a=math.tau*i/n; x=math.cos(a)*w
            y=math.sin(a)*(front if math.sin(a)<0 else back)
            if math.sin(a)<-.25:
                strength=min(1,(-math.sin(a)-.25)/.25)
                y=y*(1-strength)+face_depth(x,z,w,front)*strength
            row.append(s.vertex((x,y,z),'head'))
            tex.append((max(0,min(1,x/.17+.5)),(z-1.59)/.25))
        rows.append(row); coords.append(tex)
    for j,(a,b) in enumerate(zip(rows,rows[1:])):
        for i in range(n):
            k=(i+1)%n
            s.face((a[i],a[k],b[k],b[i]),'Face',[coords[j][i],coords[j][k],coords[j+1][k],coords[j+1][i]])
    s.face(tuple(reversed(rows[0])),'Skin'); s.face(rows[-1],'Face')
    # Ears: shaped outline with concha inset and rolled edge.
    for sign in (-1,1):
        outline=[(sign*.077,-.006,1.738),(sign*.090,-.008,1.744),(sign*.100,.002,1.730),
                 (sign*.096,-.002,1.702),(sign*.085,-.011,1.690),(sign*.077,-.010,1.702)]
        centre=(sign*.086,-.012,1.719)
        for i,p in enumerate(outline): s.patch([centre,p,outline[(i+1)%len(outline)]],'Skin','head',True)
        s.line(outline+[outline[0]],.003,'Face','head',5)
        s.line([(sign*.087,-.014,1.733),(sign*.091,-.015,1.720),(sign*.086,-.015,1.709)],.002,'Lip','head',4)
        # Eyes are small almond patches fitted into the facial surface.
        cx=sign*.037; cz=1.735
        boundary=[(-.024,-.002),(-.013,.006),(0,.008),(.015,.005),(.025,-.001),(.012,-.005),(0,-.006),(-.013,-.005)]
        points=[]
        for dx,dz in boundary:
            x=cx+dx*sign; z=cz+dz
            points.append((x,face_depth(x,z,.080,.073)-.0028,z))
        center=(cx,face_depth(cx,cz,.080,.073)-.004,cz)
        eye_ring=[s.vertex(p,'head') for p in points]
        eye_center=s.vertex(center,'head')
        for j in range(len(points)):
            s.face((eye_center,eye_ring[j],eye_ring[(j+1)%len(points)]),'White')
        for radius,color,dy in [(.0067,'Iris',.001),(.0032,'Ink',.002)]:
            circle=[(cx+math.cos(i*math.tau/16)*radius,center[1]-dy,cz+math.sin(i*math.tau/16)*radius*1.10) for i in range(16)]
            ring=[s.vertex(p,'head') for p in circle]
            middle=s.vertex((cx,center[1]-dy,cz),'head')
            for j in range(16): s.face((middle,ring[j],ring[(j+1)%16]),color)
        s.patch([(cx-.003,center[1]-.003,cz+.004),(cx-.0005,center[1]-.003,cz+.004),(cx-.0005,center[1]-.003,cz+.002)],'White','head')
        s.line([(x,y-.001,z) for x,y,z in points[:5]],.00065,'Hair','head',4)
        s.line([(x,y-.0005,z) for x,y,z in points[4:]+[points[0]]],.0004,'Lip','head',4)
        brow=[(sign*.014,-.077,1.756),(sign*.034,-.078,1.762),(sign*.053,-.074,1.762),(sign*.068,-.068,1.757)]
        s.strap(brow,.0045,'Hair','head')
        s.line([(sign*.007,-.092,1.681),(sign*.012,-.086,1.680)],.0005,'Lip','head',4)
    s.line([(-.021,-.074,1.649),(-.009,-.079,1.648),(0,-.080,1.649),(.009,-.079,1.648),(.021,-.074,1.650)],.00045,'Lip','head',5)
    s.line([(-.012,-.077,1.645),(0,-.080,1.644),(.012,-.077,1.646)],.0005,'Face','head',4)


def hair_lock(s,path,widths,color='Hair',side=(1,0,0)):
    path=catmull(path,3); rows=[]; n=5; across=Vector(side).normalized()
    for j,center in enumerate(path):
        t=j/(len(path)-1)*(len(widths)-1); index=min(int(t),len(widths)-2); f=t-index
        width=widths[index]*(1-f)+widths[index+1]*f
        row=[]
        for k in range(n):
            u=k/(n-1)*2-1
            p=center+across*(u*width)
            p+=Vector((0,-.007*(1-u*u),.004*(1-u*u)))
            row.append(s.vertex(p,'head'))
        rows.append(row)
    for j,(a,b) in enumerate(zip(rows,rows[1:])):
        for k in range(n-1):
            s.face((a[k],a[k+1],b[k+1],b[k]),color,[(k/(n-1),j/(len(rows)-1)),((k+1)/(n-1),j/(len(rows)-1)),((k+1)/(n-1),(j+1)/(len(rows)-1)),(k/(n-1),(j+1)/(len(rows)-1))])
    # Back surface gives the pointed lock actual volume, with a shared tip.
    for edge in (0,n-1):
        for a,b in zip(rows,rows[1:]):
            pa,pb=Vector(s.v[a[edge]]),Vector(s.v[b[edge]])
            s.patch([pa,pb,pb+Vector((0,.006,-.003)),pa+Vector((0,.006,-.003))],color,'head',True)


def hair(s):
    # Smooth cranial cap under individually swept, tapered locks.
    s.rings([((0,.013,z),rx,ry,'head') for z,rx,ry in [(1.738,.078,.076),(1.775,.085,.083),(1.81,.080,.081),(1.845,.060,.063),(1.866,.018,.020)]],'Hair',32)
    # Rear scalp and nape coverage, leaving the forehead and ears uncovered.
    rear=[]
    for z,rx,ry in [(1.646,.065,.074),(1.68,.084,.092),(1.71,.089,.096),(1.75,.090,.097),(1.80,.083,.090)]:
        rear.append([s.vertex((rx*math.cos(i*math.pi/20),.010+ry*math.sin(i*math.pi/20),z),'head') for i in range(21)])
    for a,b in zip(rear,rear[1:]):
        for i in range(20): s.face((a[i],a[i+1],b[i+1],b[i]),'Hair')
    locks=[
      ([(-.025,.017,1.865),(-.054,-.036,1.872),(-.084,-.072,1.811),(-.097,-.080,1.753)],[.014,.030,.023,.0005]),
      ([(-.010,.018,1.873),(-.023,-.040,1.876),(-.059,-.084,1.810),(-.063,-.091,1.755)],[.014,.030,.023,.0005]),
      ([(.006,.023,1.875),(.010,-.035,1.880),(-.014,-.090,1.813),(-.036,-.094,1.768)],[.014,.030,.021,.0005]),
      ([(.020,.022,1.866),(.047,-.030,1.856),(.023,-.089,1.802),(.008,-.094,1.771)],[.013,.027,.021,.0005]),
      ([(.031,.030,1.853),(.072,-.020,1.840),(.065,-.074,1.796),(.081,-.079,1.747)],[.012,.023,.018,.0005]),
      ([(-.020,.025,1.865),(-.060,.013,1.882),(-.092,-.018,1.850),(-.121,-.025,1.832)],[.015,.026,.018,.0005]),
      ([(.018,.040,1.854),(.050,.035,1.874),(.067,.020,1.871),(.075,.008,1.880)],[.012,.022,.013,.0004]),
    ]
    for i,(path,width) in enumerate(locks): hair_lock(s,path,width,'HairLight' if i in (1,3,6) else 'Hair')
    for sign in (-1,1):
        for i in range(4):
            y=.012+i*.019
            hair_lock(s,[(sign*.043,y,1.847),(sign*.080,y+.015,1.812),(sign*.094,y+.012,1.755),(sign*(.083+.007*i),y+.016,1.699+.009*i)], [.018,.025,.020,.0005], 'HairLight' if i==1 else 'Hair',side=(.25,1,0))
        hair_lock(s,[(sign*.069,-.036,1.805),(sign*.087,-.042,1.764),(sign*.080,-.045,1.710)],[.014,.017,.0005],side=(1,0,0))
    for i in range(5):
        x=-.065+i*.032
        hair_lock(s,[(x*.6,.052,1.85),(x,.087,1.79),(x*1.2,.089,1.73),(x*1.15,.075,1.687)],[.014,.025,.021,.0005],side=(1,0,0))


def buckle(s,center,w,h,bone='spine'):
    x,y,z=center
    s.line([(x-w/2,y,z-h/2),(x+w/2,y,z-h/2),(x+w/2,y,z+h/2),(x-w/2,y,z+h/2),(x-w/2,y,z-h/2)],.0022,'Gold',bone,5)
    s.line([(x-w*.45,y-.001,z),(x+w*.30,y-.001,z)],.0014,'Silver',bone,4)


def crest(s,x,y,z,size,bone,color='Gold'):
    # Original compass-like heraldic star from the reference, expressed as trim.
    for axis in [(0,size),(size*.48,0),(size*.32,size*.32),(size*.32,-size*.32)]:
        dx,dz=axis
        s.patch([(x-dx,y,z-dz),(x-.002,y-.002,z),(x+dx,y,z+dz),(x+.002,y-.002,z)],color,bone)
    s.line([(x,y,z+size*.35),(x+size*.28,y,z),(x,y,z-size*.35),(x-size*.28,y,z),(x,y,z+size*.35)],.0012,color,bone,4)


def torso(s):
    s.rings([((0,0,z),rx,ry,w) for z,rx,ry,w in [
       (.97,.147,.080,'pelvis'),(1.055,.135,.079,{'pelvis':.7,'spine':.3}),
       (1.12,.129,.080,'spine'),(1.22,.149,.089,'spine'),(1.33,.177,.101,'spine'),
       (1.43,.191,.093,'spine'),(1.49,.154,.076,'spine'),(1.525,.058,.049,'neck')]],'Navy',24)
    s.rings([((0,0,1.50),.044,.040,'neck'),((0,0,1.57),.041,.039,'neck'),((0,-.003,1.62),.042,.040,{'neck':.5,'head':.5})],'Skin',16)
    # High open collar and tapered lapels frame the face.
    for sign in (-1,1):
        poly=[(sign*.025,-.091,1.39),(sign*.075,-.088,1.46),(sign*.088,-.045,1.565),(sign*.041,-.047,1.570),(sign*.035,-.065,1.49)]
        s.patch(poly,'BlueCloth','spine',True)
        s.line(poly[:4],.0023,'Gold','spine',5)
        # Front jacket panels define the V and tailored seams.
        s.line([(sign*.052,-.086,1.11),(sign*.074,-.095,1.23),(sign*.10,-.100,1.36),(sign*.15,-.083,1.46)],.0015,'BlueCloth','spine',4)
    s.strap([(0,-.082,1.08),(0,-.093,1.24),(0,-.106,1.37),(0,-.08,1.46)],.012,'DarkLeather','spine')
    for z in (1.16,1.24,1.32,1.40):
        s.patch([(-.004,-.109,z),(0,-.111,z+.004),(.004,-.109,z),(0,-.111,z-.004)],'Gold','spine')
    # Cross-body leather harness with slim stitched edges and brass buckle.
    path=[(-.157,-.068,1.475),(-.116,-.098,1.39),(-.04,-.114,1.29),(.045,-.101,1.20),(.113,-.083,1.105)]
    s.strap(path,.030,'Leather','spine')
    buckle(s,(-.058,-.118,1.315),.033,.044)
    path2=[(.145,-.070,1.46),(.095,-.105,1.38),(.045,-.113,1.32)]
    s.strap(path2,.018,'DarkLeather','spine'); buckle(s,(.088,-.111,1.37),.020,.028)
    # Two waist belts follow the torso, not rectangular blocks.
    for z,tilt in [(1.088,0),(1.032,.08)]:
        rows=[]
        for dz in (-.015,.015):
            rows.append([s.vertex((.151*math.cos(i*math.tau/32),.089*math.sin(i*math.tau/32),z+dz+tilt*.151*math.cos(i*math.tau/32)),'pelvis') for i in range(32)])
        for i in range(32):
            k=(i+1)%32; s.face((rows[0][i],rows[0][k],rows[1][k],rows[1][i]),'Leather',[(i/32,0),((i+1)/32,0),((i+1)/32,1),(i/32,1)])
        buckle(s,(.025,-.093,z),.042,.033,'pelvis')
    for x in (-.100,-.065,.075,.115):
        s.line([(x,-.082,1.065),(x,-.084,1.11)],.004,'Gold','pelvis',4)
    # Belt pouch and flap, softened by contour rings.
    s.rings([((-.164,-.034,z),rx,ry,'pelvis') for z,rx,ry in [(.90,.026,.024),(.91,.035,.029),(.995,.035,.029),(1.005,.027,.025)]],'Leather',8)
    s.patch([(-.197,-.066,1.0),(-.130,-.066,1.0),(-.137,-.069,.958),(-.165,-.071,.950),(-.193,-.069,.958)],'DarkLeather','pelvis')
    buckle(s,(-.164,-.074,.975),.016,.019,'pelvis')


def garments(s):
    # Split coat skirt: front remains open so legs can move independently.
    for sign in (-1,1):
        rows=[]; n=12
        for j,(z,rx,ry) in enumerate([(1.06,.151,.092),(.94,.173,.102),(.78,.198,.116),(.59,.217,.135)]):
            row=[]
            for i in range(n):
                angle=-1.03+i/(n-1)*2.58
                x=sign*rx*math.cos(angle); y=ry*math.sin(angle)
                zz=z + (.08*math.sin(angle+1.03) if j==3 else 0)
                bone={'pelvis':.6,('thigh.R' if sign>0 else 'thigh.L'):.4} if j>1 else {'pelvis':1}
                row.append(s.vertex((x,y,zz),bone))
            rows.append(row)
        for j,(a,b) in enumerate(zip(rows,rows[1:])):
            for i in range(n-1):
                s.face((a[i],a[i+1],b[i+1],b[i]),'Navy',[(i/(n-1),1-j/3),((i+1)/(n-1),1-j/3),((i+1)/(n-1),1-(j+1)/3),(i/(n-1),1-(j+1)/3)])
        outline=[s.v[row[0]] for row in rows]+[s.v[i] for i in rows[-1][1:]]
        s.line(outline,.0025,'Gold','pelvis',5)
        crest(s,sign*.142,-.117,.72,.033,'pelvis')
    # Hood resting behind the neck, constructed as a shaped cloth shell.
    s.rings([((0,.056,z),rx,ry,'spine') for z,rx,ry in [(1.37,.101,.053),(1.43,.139,.083),(1.50,.117,.073),(1.55,.073,.046)]],'Navy',24)
    hoodrim=[(-.067,.014,1.55),(-.109,.059,1.49),(-.09,.122,1.43),(0,.145,1.415),(.09,.122,1.43),(.109,.059,1.49),(.067,.014,1.55)]
    s.line(hoodrim,.006,'BlueCloth','spine',6)
    # Asymmetric mantle, with alternating broad folds rather than a flat triangle.
    rows=[]; n=13
    for j,(z,w,depth) in enumerate([(1.47,.19,.090),(1.30,.21,.13),(1.08,.23,.15),(.84,.24,.17),(.65,.25,.18)]):
        row=[]
        for i in range(n):
            u=i/(n-1); x=-.055+(u-.5)*w*2
            y=depth+.018*math.cos(u*math.pi*6)*(j/4+.2)
            zz=z + (.07*math.cos(u*math.pi) if j==4 else 0)
            bone={'spine':1-j/5,'pelvis':j/5}
            row.append(s.vertex((x,y,zz),bone))
        rows.append(row)
    for j,(a,b) in enumerate(zip(rows,rows[1:])):
        for i in range(n-1):
            s.face((a[i],a[i+1],b[i+1],b[i]),'Navy',[(i/(n-1),1-j/4),((i+1)/(n-1),1-j/4),((i+1)/(n-1),1-(j+1)/4),(i/(n-1),1-(j+1)/4)])
    for edge in (0,-1): s.line([s.v[row[edge]] for row in rows],.0024,'Gold','spine',5)
    s.line([s.v[i] for i in rows[-1]],.0024,'Gold','pelvis',5)
    crest(s,-.055,.193,.91,.045,{'spine':.4,'pelvis':.6})


def limbs(s):
    for sign,side in [(-1,'L'),(1,'R')]:
        thigh,calf,foot=[f'{b}.{side}' for b in ('thigh','calf','foot')]
        ua,fa,hand=[f'{b}.{side}' for b in ('upper_arm','forearm','hand')]
        # Trousers: anatomically tapered thigh, kneecap and calf transitions.
        s.rings([((sign*x,y,z),rx,ry,w) for x,y,z,rx,ry,w in [
            (.106,0,1.025,.086,.081,'pelvis'),(.112,0,.94,.085,.079,thigh),
            (.116,.003,.83,.074,.074,thigh),(.119,0,.71,.063,.064,thigh),
            (.122,-.012,.60,.052,.057,{thigh:.6,calf:.4}),(.121,0,.54,.052,.053,calf),
            (.120,.012,.39,.050,.055,calf),(.120,.005,.22,.038,.040,calf)]],'Trouser',16)
        # Long boot shaft, shaped ankle, instep, rounded toe and layered sole.
        s.rings([((sign*.120,y,z),rx,ry,w) for y,z,rx,ry,w in [
            (-.062,.035,.058,.120,foot),(-.063,.060,.061,.124,foot),
            (-.060,.105,.060,.117,foot),(-.025,.145,.045,.069,{foot:.7,calf:.3}),
            (.002,.20,.042,.044,calf),(.006,.35,.053,.056,calf),(.003,.48,.057,.055,calf),(-.002,.55,.055,.053,calf)]],'DarkLeather',16)
        s.rings([((sign*.12,-.063,z),rx,ry,foot) for z,rx,ry in [(.018,.058,.118),(.033,.063,.126),(.047,.061,.124)]],'Trouser',16)
        for z,rx,ry in [(.19,.045,.047),(.40,.056,.058),(.53,.058,.056)]:
            s.rings([((sign*.12,.002,z+dz),rx,ry,calf) for dz in (-.012,.012)],'Leather',16)
            buckle(s,(sign*.155,-.047,z),.022,.023,calf)
        # Kneeguard with faceted raised centre and restrained metal edging.
        outline=[(sign*.12,-.069,.640),(sign*(.12+.038),-.055,.601),(sign*.12,-.074,.558),(sign*(.12-.038),-.055,.601)]
        center=(sign*.12,-.083,.602)
        for i in range(4): s.patch([center,outline[i],outline[(i+1)%4]],'Silver',calf,False)
        s.line(outline+[outline[0]],.002,'Gold',calf,4)
        # Tailored sleeve: no spherical shoulder or elbow joints.
        s.rings([((sign*x,y,z),rx,ry,w) for x,y,z,rx,ry,w in [
            (.208,0,1.48,.065,.067,ua),(.235,0,1.43,.067,.067,ua),
            (.259,0,1.36,.058,.060,ua),(.292,-.008,1.27,.048,.052,{ua:.75,fa:.25}),
            (.304,-.020,1.23,.049,.049,{ua:.4,fa:.6}),(.318,-.031,1.19,.050,.050,fa),
            (.340,-.048,1.08,.038,.039,fa),(.353,-.057,1.035,.032,.034,fa)]],'Navy',16)
        # Forearm bracer and cuff.
        s.rings([((sign*x,y,z),rx,ry,fa) for x,y,z,rx,ry in [(.328,-.037,1.15,.050,.052),(.343,-.049,1.08,.042,.044),(.356,-.059,1.025,.036,.038)]],'DarkLeather',12)
        for x,y,z,rx in [(.328,-.037,1.15,.051),(.353,-.057,1.04,.039)]:
            s.rings([((sign*x,y,z+dz),rx,rx,fa) for dz in (-.007,.007)],'Leather',12)
            buckle(s,(sign*x,y-rx-.003,z),.021,.017,fa)
        # Palm, fingers and thumb with recognizable knuckles. Fingers stay rigid.
        s.rings([((sign*x,y,z),rx,ry,hand) for x,y,z,rx,ry in [(.356,-.060,1.035,.030,.027),(.363,-.066,.995,.034,.026),(.366,-.069,.958,.033,.021)]],'DarkLeather',12)
        if side == 'R':
            for i in range(4):
                z=.957+i*.014
                s.line(catmull([(.346,-.073,z),(.353,-.108,z),(.374,-.121,z),(.390,-.105,z),(.385,-.093,z)],2),.007,'Skin',hand,6)
            s.line(catmull([(.335,-.070,1.006),(.342,-.099,1.010),(.366,-.123,1.006),(.380,-.119,.993)],2),.009,'Skin',hand,6)
        else:
            for i in range(4):
                x=sign*(.342+i*.016); length=[.037,.047,.044,.033][i]
                s.rings([((x,y,z),rx,ry,hand) for y,z,rx,ry in [(-.071,.970,.008,.012),(-.079,.950,.009,.011),(-.085,.945-length*.5,.008,.009),(-.079,.945-length,.006,.007)]],'Skin',8)
            s.rings([((sign*x,y,z),rx,ry,hand) for x,y,z,rx,ry in [(.335,-.072,.997,.012,.013),(.325,-.094,.974,.012,.012),(.331,-.102,.953,.009,.009)]],'Skin',8)
        # Single substantial left shoulder guard; right shoulder is cloth/leather.
        if side=='L':
            for j in range(2):
                s.rings([((sign*x,y,z-j*.055),rx,ry,ua) for x,y,z,rx,ry in [(.208,0,1.535,.025,.034),(.228,0,1.513,.075,.083),(.245,-.002,1.468,.076,.080)]],'Silver',12)
                ring=[(sign*(.245+.077*math.cos(i*math.tau/24)),-.002+.081*math.sin(i*math.tau/24),1.468-j*.055) for i in range(25)]
                s.line(ring,.0022,'Gold',ua,5)
        else:
            s.rings([((sign*.223,0,1.49),.070,.073,ua),((sign*.249,0,1.42),.070,.072,ua)],'BlueCloth',12)


def sword(s):
    x=.375; y=-.103; z=.985; bone='hand.R'
    s.rings([((x,y,zz),r,r,bone) for zz,r in [(z-.08,.013),(z-.06,.012),(z+.035,.012),(z+.045,.016)]],'DarkLeather',10)
    for i in range(6):
        zz=z-.055+i*.014
        s.rings([((x,y,k),.0135,.0135,bone) for k in (zz,zz+.003)],'Gold',8)
    # Diamond-section blade: reflective edges and inset blue core.
    rings=[]
    for zz,w,depth in [(z+.07,.035,.008),(z+.13,.029,.007),(z+.62,.019,.004),(z+.79,.0005,.0005)]:
        rings.append([s.vertex((x-w,y,zz),bone),s.vertex((x,y-depth,zz),bone),s.vertex((x+w,y,zz),bone),s.vertex((x,y+depth,zz),bone)])
    for a,b in zip(rings,rings[1:]):
        for i in range(4): s.face((a[i],a[(i+1)%4],b[(i+1)%4],b[i]),'Silver',smooth=False)
    s.patch([(x-.007,y-.0085,z+.14),(x,y-.009,z+.68),(x+.007,y-.0085,z+.14),(x,y-.009,z+.10)],'Crystal',bone)
    for sign in (-1,1):
        path=[(x,y,z+.055),(x+sign*.040,y,z+.085),(x+sign*.085,y,z+.045),(x+sign*.105,y,z+.065)]
        s.line(catmull(path,3),.007,'Gold',bone,6)
        s.line([(x,y,z+.07),(x+sign*.022,y,z+.115),(x+sign*.027,y,z+.15)],.004,'Gold',bone,5)
    for zz,size in [(z+.06,.026),(z-.085,.017)]:
        diamond=[(x,y-.012,zz+size),(x+size*.65,y-.012,zz),(x,y-.012,zz-size),(x-size*.65,y-.012,zz)]
        for i in range(4): s.patch([(x,y-.026,zz),diamond[i],diamond[(i+1)%4]],'Crystal',bone,False)
        s.line(diamond+[diamond[0]],.003,'Gold',bone,5)


def build():
    body=Surface(); torso(body); limbs(body); garments(body); head(body); hair(body)
    blade=Surface(); sword(blade)
    return body,blade
